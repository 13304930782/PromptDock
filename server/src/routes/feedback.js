const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const db = require('../db');
const config = require('../config');
const { sendFeedbackNotification } = require('../lib/mailer');
const { getSetting } = require('../lib/settings');
const { requireAdmin, requireOwner } = require('../middleware/auth');
const { string } = require('../lib/validation');

const router = express.Router();
const adminRouter = express.Router();
const FEEDBACK_COOKIE = 'cuegrove_feedback';
const FEEDBACK_COOKIE_MAX_AGE = 180 * 24 * 60 * 60 * 1000;
const categories = new Set(['bug', 'idea', 'ux', 'performance', 'other']);
const submitLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many feedback reports were submitted. Please try again later.' },
});

const replyLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many replies were submitted. Please try again later.' },
});

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function feedbackPortalUrl(token, reportId) {
  const fragment = new URLSearchParams({ token });
  if (reportId) fragment.set('report', String(reportId));
  return `${config.siteUrl}/feedback/portal#${fragment}`;
}

function feedbackCookieOptions() {
  return {
    httpOnly: true,
    secure: config.cookie.secure,
    sameSite: 'strict',
    path: '/api/feedback',
    maxAge: FEEDBACK_COOKIE_MAX_AGE,
  };
}

async function issueFeedbackToken(applicationId, revokeExisting = true) {
  const token = crypto.randomBytes(32).toString('base64url');
  if (revokeExisting) {
    await db.query(
      `UPDATE feedback_access_tokens
       SET revoked_at=NOW()
       WHERE application_id=? AND revoked_at IS NULL`,
      [applicationId],
    );
  }
  await db.query(
    `INSERT INTO feedback_access_tokens (application_id, token_hash, expires_at)
     VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 180 DAY))`,
    [applicationId, hashToken(token)],
  );
  return token;
}

async function resolveToken(token) {
  const clean = string(token, 160);
  if (!/^[A-Za-z0-9_-]{40,80}$/.test(clean)) return null;
  const [rows] = await db.query(
    `SELECT fat.application_id, fat.expires_at, ea.full_name, ea.email, ea.cohort
     FROM feedback_access_tokens fat
     JOIN early_access_applications ea ON ea.id=fat.application_id
     WHERE fat.token_hash=? AND fat.revoked_at IS NULL AND ea.status='approved'
       AND (fat.expires_at IS NULL OR fat.expires_at > NOW())
     LIMIT 1`,
    [hashToken(clean)],
  );
  return rows[0] || null;
}

async function resolveRequestAccess(req) {
  return resolveToken(req.params.token || req.cookies?.[FEEDBACK_COOKIE]);
}

async function ownerRecipient() {
  const settings = await getSetting('early_access');
  if (settings.notify_email) return { name: 'CueGrove Owner', email: settings.notify_email };
  const [rows] = await db.query(
    "SELECT name, email FROM admin_users WHERE role='owner' AND status='active' ORDER BY id LIMIT 1",
  );
  return rows[0] || null;
}

async function messagesForReports(reportIds) {
  if (!reportIds.length) return new Map();
  const [rows] = await db.query(
    `SELECT fm.id, fm.report_id, fm.author_type, fm.body, fm.created_at, au.name AS admin_name
     FROM feedback_messages fm
     LEFT JOIN admin_users au ON au.id=fm.admin_id
     WHERE fm.report_id IN (?)
     ORDER BY fm.created_at ASC, fm.id ASC`,
    [reportIds],
  );
  return rows.reduce((map, message) => {
    const items = map.get(message.report_id) || [];
    items.push(message);
    map.set(message.report_id, items);
    return map;
  }, new Map());
}

async function reportsForApplication(applicationId) {
  const [reports] = await db.query(
    `SELECT * FROM feedback_reports
     WHERE application_id=?
     ORDER BY updated_at DESC, id DESC`,
    [applicationId],
  );
  const messages = await messagesForReports(reports.map((report) => report.id));
  return reports.map((report) => ({ ...report, messages: messages.get(report.id) || [] }));
}

router.post('/session', submitLimit, async (req, res, next) => {
  try {
    const token = string(req.body.token, 160);
    const access = await resolveToken(token);
    if (!access) return res.status(404).json({ message: 'This feedback link is invalid or expired.' });
    res.cookie(FEEDBACK_COOKIE, token, feedbackCookieOptions());
    return res.json({ message: 'Feedback access ready.' });
  } catch (error) {
    return next(error);
  }
});

async function listFeedback(req, res, next) {
  try {
    const access = await resolveRequestAccess(req);
    if (!access) return res.status(404).json({ message: 'This feedback link is invalid or expired.' });
    const reports = await reportsForApplication(access.application_id);
    return res.json({ feedback: { name: access.full_name, cohort: access.cohort, reports } });
  } catch (error) {
    return next(error);
  }
}

router.get('/', listFeedback);
router.get('/:token([A-Za-z0-9_-]{40,80})', listFeedback);

async function submitFeedback(req, res, next) {
  try {
    const access = await resolveRequestAccess(req);
    if (!access) return res.status(404).json({ message: 'This feedback link is invalid or expired.' });

    const category = string(req.body.category, 30);
    const title = string(req.body.title, 160);
    const details = string(req.body.details, 8000);
    const steps = string(req.body.steps, 4000);
    const expected = string(req.body.expected, 4000);
    const actual = string(req.body.actual, 4000);
    const device = string(req.body.device, 120);
    const macosVersion = string(req.body.macos_version, 80);
    const appBuild = string(req.body.app_build, 80);

    if (!categories.has(category)) return res.status(400).json({ message: 'Choose a feedback category.' });
    if (title.length < 3 || details.length < 10) {
      return res.status(400).json({ message: 'Please provide a title and at least a few details.' });
    }

    const [result] = await db.query(
      `INSERT INTO feedback_reports
       (application_id, category, title, details, steps, expected, actual, device, macos_version, app_build)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [access.application_id, category, title, details, steps || null, expected || null, actual || null, device || null, macosVersion || null, appBuild || null],
    );
    const owner = await ownerRecipient();
    const delivery = owner ? await sendFeedbackNotification({
      applicationId: access.application_id,
      to: owner.email,
      actor: 'tester',
      locale: 'zh',
      recipientName: owner.name,
      reportTitle: title,
      actionUrl: `${config.siteUrl}/admin/feedback?report=${result.insertId}`,
      isNewReport: true,
    }) : { status: 'skipped' };
    return res.status(201).json({ message: 'Thanks — your feedback was received.', email_status: delivery.status });
  } catch (error) {
    return next(error);
  }
}

router.post('/', submitLimit, submitFeedback);
router.post('/:token([A-Za-z0-9_-]{40,80})', submitLimit, submitFeedback);

async function submitReply(req, res, next) {
  try {
    const access = await resolveRequestAccess(req);
    if (!access) return res.status(404).json({ message: 'This feedback link is invalid or expired.' });
    const id = Number(req.params.id);
    const body = string(req.body.body, 4000);
    if (!Number.isInteger(id) || id < 1 || body.length < 1) {
      return res.status(400).json({ message: 'Reply text is required.' });
    }
    const [reports] = await db.query(
      'SELECT id, application_id, title FROM feedback_reports WHERE id=? AND application_id=? LIMIT 1',
      [id, access.application_id],
    );
    const report = reports[0];
    if (!report) return res.status(404).json({ message: 'Feedback report not found.' });
    await db.query(
      "INSERT INTO feedback_messages (report_id, author_type, body) VALUES (?, 'tester', ?)",
      [id, body],
    );
    await db.query("UPDATE feedback_reports SET status='new', updated_at=NOW() WHERE id=?", [id]);
    const owner = await ownerRecipient();
    const delivery = owner ? await sendFeedbackNotification({
      applicationId: access.application_id,
      to: owner.email,
      actor: 'tester',
      locale: 'zh',
      recipientName: owner.name,
      reportTitle: report.title,
      actionUrl: `${config.siteUrl}/admin/feedback?report=${id}`,
      isNewReport: false,
    }) : { status: 'skipped' };
    return res.status(201).json({ message: 'Reply sent.', email_status: delivery.status });
  } catch (error) {
    return next(error);
  }
}

router.post('/:id(\\d+)/replies', replyLimit, submitReply);
router.post('/:token([A-Za-z0-9_-]{40,80})/:id/replies', replyLimit, submitReply);

adminRouter.use(requireAdmin, requireOwner);

adminRouter.get('/', async (req, res, next) => {
  try {
    const status = ['new', 'triaged', 'resolved', 'all'].includes(req.query.status) ? req.query.status : 'new';
    const keyword = string(req.query.keyword, 100);
    const conditions = [];
    const params = [];
    if (status !== 'all') { conditions.push('fr.status=?'); params.push(status); }
    if (keyword) {
      const match = `%${keyword}%`;
      conditions.push('(ea.full_name LIKE ? OR ea.email LIKE ? OR fr.title LIKE ? OR fr.details LIKE ?)');
      params.push(match, match, match, match);
    }
    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const [rows] = await db.query(
      `SELECT fr.*, ea.full_name, ea.email, ea.cohort,
              (SELECT COUNT(*) FROM feedback_messages fm WHERE fm.report_id=fr.id) AS message_count
       FROM feedback_reports fr JOIN early_access_applications ea ON ea.id=fr.application_id
       ${where} ORDER BY fr.created_at DESC LIMIT 300`,
      params,
    );
    res.json({ reports: rows });
  } catch (error) {
    next(error);
  }
});

adminRouter.get('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Feedback report id is invalid.' });
    const [rows] = await db.query(
      `SELECT fr.*, ea.full_name, ea.email, ea.locale, ea.cohort
       FROM feedback_reports fr
       JOIN early_access_applications ea ON ea.id=fr.application_id
       WHERE fr.id=? LIMIT 1`,
      [id],
    );
    if (!rows[0]) return res.status(404).json({ message: 'Feedback report not found.' });
    const messages = await messagesForReports([id]);
    res.json({ report: { ...rows[0], messages: messages.get(id) || [] } });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/:id/replies', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const body = string(req.body.body, 4000);
    if (!Number.isInteger(id) || id < 1 || body.length < 1) {
      return res.status(400).json({ message: 'Reply text is required.' });
    }
    const [rows] = await db.query(
      `SELECT fr.id, fr.application_id, fr.title, ea.full_name, ea.email, ea.locale
       FROM feedback_reports fr
       JOIN early_access_applications ea ON ea.id=fr.application_id
       WHERE fr.id=? LIMIT 1`,
      [id],
    );
    const report = rows[0];
    if (!report) return res.status(404).json({ message: 'Feedback report not found.' });
    const replyToken = await issueFeedbackToken(report.application_id, false);
    await db.query(
      "INSERT INTO feedback_messages (report_id, author_type, admin_id, body) VALUES (?, 'developer', ?, ?)",
      [id, req.admin.id, body],
    );
    await db.query('UPDATE feedback_reports SET updated_at=NOW() WHERE id=?', [id]);
    const delivery = await sendFeedbackNotification({
      applicationId: report.application_id,
      to: report.email,
      actor: 'developer',
      locale: report.locale,
      recipientName: report.full_name,
      reportTitle: report.title,
      actionUrl: feedbackPortalUrl(replyToken, id),
      isNewReport: false,
    });
    res.status(201).json({ message: 'Reply sent.', email_status: delivery.status });
  } catch (error) {
    next(error);
  }
});

adminRouter.patch('/:id', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const status = string(req.body.status, 20);
    if (!Number.isInteger(id) || id < 1 || !['new', 'triaged', 'resolved'].includes(status)) {
      return res.status(400).json({ message: 'Feedback status is invalid.' });
    }
    const [result] = await db.query('UPDATE feedback_reports SET status=? WHERE id=?', [status, id]);
    if (!result.affectedRows) return res.status(404).json({ message: 'Feedback report not found.' });
    res.json({ message: 'Feedback status updated.' });
  } catch (error) {
    next(error);
  }
});

module.exports = {
  router,
  adminRouter,
  feedbackPortalUrl,
  issueFeedbackToken,
};
