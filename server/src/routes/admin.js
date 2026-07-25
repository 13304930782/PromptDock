const express = require('express');
const db = require('../db');
const config = require('../config');
const { requireAdmin } = require('../middleware/auth');
const { getSetting, saveSetting } = require('../lib/settings');
const { mailReady, sendDecisionEmail, sendTestEmail } = require('../lib/mailer');
const { isEmail, isHttpUrl, normalizeEmail, string } = require('../lib/validation');

const router = express.Router();
router.use(requireAdmin);

const applicationSelect = `
  SELECT
    ea.*,
    reviewer.name AS reviewer_name,
    (
      SELECT mdl.status
      FROM mail_delivery_logs mdl
      WHERE mdl.application_id=ea.id AND mdl.mail_kind IN ('approved','rejected')
      ORDER BY mdl.id DESC
      LIMIT 1
    ) AS latest_email_status,
    (
      SELECT mdl.error_message
      FROM mail_delivery_logs mdl
      WHERE mdl.application_id=ea.id AND mdl.mail_kind IN ('approved','rejected')
      ORDER BY mdl.id DESC
      LIMIT 1
    ) AS latest_email_error
  FROM early_access_applications ea
  LEFT JOIN admin_users reviewer ON reviewer.id=ea.reviewer_id
`;

router.get('/early-access', async (req, res, next) => {
  try {
    const status = string(req.query.status, 20) || 'pending';
    const keyword = string(req.query.keyword, 100);
    if (!['all', 'pending', 'approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: 'Application status filter is invalid.' });
    }

    const where = [];
    const params = [];
    if (status !== 'all') {
      where.push('ea.status=?');
      params.push(status);
    }
    if (keyword) {
      const match = `%${keyword}%`;
      where.push('(ea.full_name LIKE ? OR ea.email LIKE ? OR ea.role LIKE ? OR ea.use_case LIKE ? OR ea.motivation LIKE ?)');
      params.push(match, match, match, match, match);
    }

    const [rows] = await db.query(
      `${applicationSelect}
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY CASE WHEN ea.status='pending' THEN 0 ELSE 1 END, ea.created_at DESC
       LIMIT 300`,
      params,
    );
    res.json({ applications: rows });
  } catch (error) {
    next(error);
  }
});

router.patch('/early-access/:id/review', async (req, res, next) => {
  const id = Number(req.params.id);
  const decision = req.body.decision;
  const internalNote = string(req.body.internal_note, 2000);
  const applicantMessage = string(req.body.applicant_message, 1500);
  if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Application id is invalid.' });
  if (!['approved', 'rejected'].includes(decision)) return res.status(400).json({ message: 'Decision must be approved or rejected.' });

  let application;
  let settings;
  const connection = await db.getConnection();
  try {
    settings = await getSetting('early_access');
    if (decision === 'approved' && !settings.download_url) {
      return res.status(409).json({ message: 'Configure the PromptDock download URL before approving applications.' });
    }

    await connection.beginTransaction();
    const [rows] = await connection.query(
      'SELECT * FROM early_access_applications WHERE id=? FOR UPDATE',
      [id],
    );
    application = rows[0];
    if (!application) {
      await connection.rollback();
      return res.status(404).json({ message: 'Application not found.' });
    }
    if (application.status !== 'pending') {
      await connection.rollback();
      return res.status(409).json({ message: 'This application has already been reviewed.' });
    }
    await connection.query(
      `UPDATE early_access_applications
       SET status=?, reviewer_id=?, internal_note=?, applicant_message=?, reviewed_at=NOW()
       WHERE id=?`,
      [decision, req.admin.id, internalNote || null, applicantMessage || null, id],
    );
    await connection.commit();
    application = {
      ...application,
      status: decision,
      reviewer_id: req.admin.id,
      internal_note: internalNote,
      applicant_message: applicantMessage,
    };
  } catch (error) {
    await connection.rollback().catch(() => undefined);
    return next(error);
  } finally {
    connection.release();
  }

  try {
    const delivery = await sendDecisionEmail(application, settings);
    return res.json({
      message: decision === 'approved' ? 'Application approved.' : 'Application rejected.',
      email_status: delivery.status,
      email_error: delivery.error || null,
    });
  } catch (error) {
    return next(error);
  }
});

router.post('/early-access/:id/retry-email', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Application id is invalid.' });
    const [rows] = await db.query('SELECT * FROM early_access_applications WHERE id=? LIMIT 1', [id]);
    const application = rows[0];
    if (!application) return res.status(404).json({ message: 'Application not found.' });
    if (!['approved', 'rejected'].includes(application.status)) {
      return res.status(409).json({ message: 'Only reviewed applications have a decision email.' });
    }
    const [logRows] = await db.query(
      `SELECT status FROM mail_delivery_logs
       WHERE application_id=? AND mail_kind IN ('approved','rejected')
       ORDER BY id DESC LIMIT 1`,
      [id],
    );
    if (logRows[0]?.status !== 'failed') {
      return res.status(409).json({ message: 'Only a failed decision email can be retried.' });
    }
    const settings = await getSetting('early_access');
    if (application.status === 'approved' && !settings.download_url) {
      return res.status(409).json({ message: 'Configure the PromptDock download URL before retrying this email.' });
    }
    const delivery = await sendDecisionEmail(application, settings);
    if (delivery.status === 'failed') {
      return res.status(502).json({ message: `Email delivery failed: ${delivery.error}` });
    }
    return res.json({ message: 'Decision email sent.' });
  } catch (error) {
    next(error);
  }
});

router.get('/settings/early-access', async (_req, res, next) => {
  try {
    res.json({ settings: await getSetting('early_access') });
  } catch (error) {
    next(error);
  }
});

router.put('/settings/early-access', async (req, res, next) => {
  try {
    const cohort = string(req.body.cohort, 80);
    const downloadUrl = string(req.body.download_url, 500);
    const feedbackUrl = string(req.body.feedback_url, 500);
    const notifyEmail = normalizeEmail(req.body.notify_email);
    if (!cohort || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{2,79}$/.test(cohort)) {
      return res.status(400).json({ message: 'Cohort must use 3–80 letters, numbers, dots, underscores, or hyphens.' });
    }
    if (!isHttpUrl(downloadUrl)) return res.status(400).json({ message: 'Download URL must be a valid HTTP or HTTPS URL.' });
    if (!isHttpUrl(feedbackUrl)) return res.status(400).json({ message: 'Feedback URL must be a valid HTTP or HTTPS URL.' });
    if (notifyEmail && !isEmail(notifyEmail)) return res.status(400).json({ message: 'Notification email is invalid.' });

    const settings = {
      applications_open: req.body.applications_open === true,
      cohort,
      download_url: downloadUrl,
      feedback_url: feedbackUrl,
      notify_email: notifyEmail,
      notify_on_new_application: req.body.notify_on_new_application === true,
    };
    await saveSetting('early_access', settings);
    res.json({ settings });
  } catch (error) {
    next(error);
  }
});

router.get('/settings/mail/status', (_req, res) => {
  res.json({
    mail: {
      enabled: mailReady(),
      host_configured: Boolean(config.mail.host),
      user_configured: Boolean(config.mail.user),
      password_configured: Boolean(config.mail.pass),
      from: config.mail.from,
    },
  });
});

router.post('/settings/mail/test', async (req, res, next) => {
  try {
    const settings = await getSetting('early_access');
    const recipient = settings.notify_email || req.admin.email;
    const delivery = await sendTestEmail(recipient);
    if (delivery.status === 'failed') {
      return res.status(502).json({ message: `Test email failed: ${delivery.error}` });
    }
    res.json({ message: `Test email sent to ${recipient}.` });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
