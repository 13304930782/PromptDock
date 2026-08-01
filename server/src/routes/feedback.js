const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const db = require('../db');
const { requireAdmin, requireOwner } = require('../middleware/auth');
const { string } = require('../lib/validation');

const router = express.Router();
const adminRouter = express.Router();
const categories = new Set(['bug', 'idea', 'ux', 'performance', 'other']);
const submitLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many feedback reports were submitted. Please try again later.' },
});

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function issueFeedbackToken(applicationId) {
  const [existing] = await db.query(
    'SELECT id FROM feedback_access_tokens WHERE application_id=? LIMIT 1',
    [applicationId],
  );
  const token = crypto.randomBytes(32).toString('base64url');
  if (existing[0]) {
    await db.query(
      `UPDATE feedback_access_tokens
       SET token_hash=?, expires_at=DATE_ADD(NOW(), INTERVAL 180 DAY), revoked_at=NULL
       WHERE id=?`,
      [hashToken(token), existing[0].id],
    );
  } else {
    await db.query(
      `INSERT INTO feedback_access_tokens (application_id, token_hash, expires_at)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 180 DAY))`,
      [applicationId, hashToken(token)],
    );
  }
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

router.get('/:token([A-Za-z0-9_-]{40,80})', async (req, res, next) => {
  try {
    const access = await resolveToken(req.params.token);
    if (!access) return res.status(404).json({ message: 'This feedback link is invalid or expired.' });
    res.json({ feedback: { name: access.full_name, cohort: access.cohort } });
  } catch (error) {
    next(error);
  }
});

router.post('/:token([A-Za-z0-9_-]{40,80})', submitLimit, async (req, res, next) => {
  try {
    const access = await resolveToken(req.params.token);
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

    await db.query(
      `INSERT INTO feedback_reports
       (application_id, category, title, details, steps, expected, actual, device, macos_version, app_build)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [access.application_id, category, title, details, steps || null, expected || null, actual || null, device || null, macosVersion || null, appBuild || null],
    );
    res.status(201).json({ message: 'Thanks — your feedback was received.' });
  } catch (error) {
    next(error);
  }
});

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
      `SELECT fr.*, ea.full_name, ea.email, ea.cohort
       FROM feedback_reports fr JOIN early_access_applications ea ON ea.id=fr.application_id
       ${where} ORDER BY fr.created_at DESC LIMIT 300`,
      params,
    );
    res.json({ reports: rows });
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

module.exports = { router, adminRouter, issueFeedbackToken };
