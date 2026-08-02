const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const config = require('../config');
const { requireAdmin, requireOwner } = require('../middleware/auth');
const { getSetting, saveSetting } = require('../lib/settings');
const { mailReady, resolveMailConfig, sendDecisionEmail, sendTestEmail } = require('../lib/mailer');
const { encryptSecret } = require('../lib/secrets');
const { feedbackPortalUrl, issueFeedbackToken } = require('./feedback');
const { isEmail, isHttpUrl, normalizeEmail, passwordError, string } = require('../lib/validation');

const router = express.Router();
router.use(requireAdmin);

function publicManagedAdmin(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    failed_login_count: user.failed_login_count,
    locked_until: user.locked_until,
    last_login_at: user.last_login_at,
    created_at: user.created_at,
    mfa_enabled: Boolean(user.mfa_enabled_at),
  };
}

function mailboxEmail(value) {
  const source = string(value, 255);
  const bracketed = source.match(/<([^<>]+)>$/);
  return bracketed ? normalizeEmail(bracketed[1]) : normalizeEmail(source);
}

function validMailHost(value) {
  return !value || /^[a-zA-Z0-9][a-zA-Z0-9.-]{0,253}$/.test(value);
}

function publicMailSettings(stored, resolved) {
  return {
    configured: stored.configured === true,
    source: resolved.source,
    enabled: resolved.enabled === true,
    ready: mailReady(resolved),
    host: resolved.host,
    port: resolved.port,
    secure: resolved.secure === true,
    auth_required: resolved.authRequired === true,
    timeout_ms: resolved.timeoutMs,
    helo_name: resolved.heloName,
    user: resolved.user,
    password_configured: Boolean(resolved.pass),
    from: resolved.from,
    reply_to: resolved.replyTo,
    configuration_error: resolved.configurationError || '',
  };
}

router.get('/users', requireOwner, async (_req, res, next) => {
  try {
    const [rows] = await db.query(
      `SELECT id, name, email, role, status, failed_login_count, locked_until, last_login_at, created_at, mfa_enabled_at
       FROM admin_users ORDER BY CASE WHEN role='owner' THEN 0 ELSE 1 END, created_at ASC`,
    );
    res.json({ users: rows.map(publicManagedAdmin) });
  } catch (error) {
    next(error);
  }
});

router.post('/users', requireOwner, async (req, res, next) => {
  try {
    const name = string(req.body.name, 80);
    const email = normalizeEmail(req.body.email);
    const role = req.body.role === 'owner' ? 'owner' : 'admin';
    const password = req.body.password;
    if (name.length < 2) return res.status(400).json({ message: 'Administrator name must contain at least 2 characters.' });
    if (!isEmail(email)) return res.status(400).json({ message: 'Administrator email is invalid.' });
    const invalidPassword = passwordError(password);
    if (invalidPassword) return res.status(400).json({ message: invalidPassword });
    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await db.query(
      `INSERT INTO admin_users (name, email, password_hash, role, status)
       VALUES (?, ?, ?, ?, 'active')`,
      [name, email, passwordHash, role],
    );
    const [rows] = await db.query(
      `SELECT id, name, email, role, status, failed_login_count, locked_until, last_login_at, created_at, mfa_enabled_at
       FROM admin_users WHERE id=? LIMIT 1`,
      [result.insertId],
    );
    res.status(201).json({ user: publicManagedAdmin(rows[0]) });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'An administrator with this email already exists.' });
    next(error);
  }
});

router.patch('/users/:id', requireOwner, async (req, res, next) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Administrator id is invalid.' });
  const name = string(req.body.name, 80);
  const email = normalizeEmail(req.body.email);
  const role = req.body.role;
  const status = req.body.status;
  if (name.length < 2) return res.status(400).json({ message: 'Administrator name must contain at least 2 characters.' });
  if (!isEmail(email)) return res.status(400).json({ message: 'Administrator email is invalid.' });
  if (!['owner', 'admin'].includes(role)) return res.status(400).json({ message: 'Administrator role is invalid.' });
  if (!['active', 'disabled'].includes(status)) return res.status(400).json({ message: 'Administrator status is invalid.' });
  if (id === req.admin.id && status === 'disabled') {
    return res.status(409).json({ message: 'You cannot disable your own administrator account.' });
  }

  let connection;
  try {
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query('SELECT * FROM admin_users WHERE id=? FOR UPDATE', [id]);
    const current = rows[0];
    if (!current) {
      await connection.rollback();
      return res.status(404).json({ message: 'Administrator not found.' });
    }
    const removesActiveOwner = current.role === 'owner' && current.status === 'active' && (role !== 'owner' || status !== 'active');
    if (removesActiveOwner) {
      const [ownerRows] = await connection.query(
        "SELECT id FROM admin_users WHERE role='owner' AND status='active' FOR UPDATE",
      );
      if (ownerRows.length <= 1) {
        await connection.rollback();
        return res.status(409).json({ message: 'At least one active owner account is required.' });
      }
    }
    await connection.query(
      `UPDATE admin_users
       SET name=?, email=?, role=?, status=?,
           failed_login_count=IF(?='active', 0, failed_login_count),
           locked_until=IF(?='active', NULL, locked_until)
       WHERE id=?`,
      [name, email, role, status, status, status, id],
    );
    await connection.commit();
    const [updatedRows] = await db.query(
      `SELECT id, name, email, role, status, failed_login_count, locked_until, last_login_at, created_at, mfa_enabled_at
       FROM admin_users WHERE id=? LIMIT 1`,
      [id],
    );
    res.json({ user: publicManagedAdmin(updatedRows[0]) });
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ message: 'An administrator with this email already exists.' });
    next(error);
  } finally {
    if (connection) connection.release();
  }
});

router.post('/users/:id/reset-password', requireOwner, async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Administrator id is invalid.' });
    const invalidPassword = passwordError(req.body.password);
    if (invalidPassword) return res.status(400).json({ message: invalidPassword });
    const passwordHash = await bcrypt.hash(req.body.password, 12);
    const [result] = await db.query(
      `UPDATE admin_users
       SET password_hash=?, failed_login_count=0, locked_until=NULL,
           token_version=token_version+1
       WHERE id=?`,
      [passwordHash, id],
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'Administrator not found.' });
    await db.query('UPDATE admin_password_resets SET used_at=NOW() WHERE admin_id=? AND used_at IS NULL', [id]);
    console.info(`[admin/password-reset] ${new Date().toISOString()} actor=${req.admin.id} target=${id}`);
    res.json({ message: 'Administrator password updated and account lock cleared.' });
  } catch (error) {
    next(error);
  }
});

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
  let feedbackToken;
  let connection;
  try {
    settings = await getSetting('early_access');
    if (decision === 'approved' && !settings.download_url) {
      return res.status(409).json({ message: 'Configure the PromptDock download URL before approving applications.' });
    }

    connection = await db.getConnection();
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
    if (decision === 'approved') {
      feedbackToken = await issueFeedbackToken(id);
    }
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    return next(error);
  } finally {
    if (connection) connection.release();
  }

  try {
    const deliverySettings = feedbackToken
      ? { ...settings, feedback_url: feedbackPortalUrl(feedbackToken) }
      : settings;
    const delivery = await sendDecisionEmail(application, deliverySettings);
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
    if (logRows[0]?.status === 'sent') {
      return res.status(409).json({ message: 'The latest decision email was already sent.' });
    }
    const settings = await getSetting('early_access');
    if (application.status === 'approved' && !settings.download_url) {
      return res.status(409).json({ message: 'Configure the PromptDock download URL before retrying this email.' });
    }
    const feedbackToken = application.status === 'approved' ? await issueFeedbackToken(id) : null;
    const deliverySettings = feedbackToken
      ? { ...settings, feedback_url: feedbackPortalUrl(feedbackToken) }
      : settings;
    const delivery = await sendDecisionEmail(application, deliverySettings);
    if (delivery.status === 'failed') {
      return res.status(502).json({ message: `Email delivery failed: ${delivery.error}` });
    }
    return res.json({ message: 'Decision email sent.' });
  } catch (error) {
    next(error);
  }
});

router.post('/early-access/resend-approved', requireOwner, async (req, res, next) => {
  if (req.body?.confirm !== true) {
    return res.status(400).json({ message: 'Explicit confirmation is required before resending approval emails.' });
  }

  const hasRequestedIds = Array.isArray(req.body.ids);
  const requestedIds = hasRequestedIds
    ? [...new Set(req.body.ids.map(Number).filter((id) => Number.isInteger(id) && id > 0))]
    : null;
  if (hasRequestedIds && requestedIds.length === 0) {
    return res.status(400).json({ message: 'Select at least one approved application.' });
  }
  if (requestedIds && requestedIds.length > 1000) {
    return res.status(400).json({ message: 'You can resend at most 1000 approval emails at once.' });
  }

  try {
    const settings = await getSetting('early_access');
    if (!settings.download_url) {
      return res.status(409).json({ message: 'Configure the PromptDock download URL before resending approval emails.' });
    }

    const params = requestedIds || [];
    const [applications] = await db.query(
      `SELECT * FROM early_access_applications
       WHERE status='approved' ${requestedIds ? `AND id IN (${requestedIds.map(() => '?').join(',')})` : ''}
       ORDER BY id ASC
       LIMIT 1000`,
      params,
    );

    const results = [];
    for (const application of applications) {
      try {
        const feedbackToken = await issueFeedbackToken(application.id);
        const delivery = await sendDecisionEmail(application, {
          ...settings,
          feedback_url: feedbackPortalUrl(feedbackToken),
        });
        results.push({ id: application.id, status: delivery.status, error: delivery.error || null });
      } catch (error) {
        results.push({ id: application.id, status: 'failed', error: String(error.message || 'Email delivery failed.') });
      }
    }

    const sent = results.filter((item) => item.status === 'sent').length;
    const failed = results.length - sent;
    return res.json({
      message: `Resent approval emails: ${sent} sent, ${failed} failed.`,
      total: results.length,
      sent,
      failed,
      results,
    });
  } catch (error) {
    return next(error);
  }
});

router.get('/settings/early-access', async (_req, res, next) => {
  try {
    res.json({ settings: await getSetting('early_access') });
  } catch (error) {
    next(error);
  }
});

router.put('/settings/early-access', requireOwner, async (req, res, next) => {
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

router.get('/settings/mail', requireOwner, async (_req, res, next) => {
  try {
    const [stored, resolved] = await Promise.all([
      getSetting('mail_transport'),
      resolveMailConfig(),
    ]);
    res.json({ settings: publicMailSettings(stored, resolved) });
  } catch (error) {
    next(error);
  }
});

router.put('/settings/mail', requireOwner, async (req, res, next) => {
  try {
    const current = await getSetting('mail_transport');
    const enabled = req.body.enabled === true;
    const host = string(req.body.host, 255).toLowerCase();
    const port = Number(req.body.port);
    const timeoutMs = Number(req.body.timeout_ms);
    const secure = req.body.secure === true;
    const authRequired = req.body.auth_required === true;
    const heloName = string(req.body.helo_name, 255).toLowerCase();
    const user = string(req.body.user, 255);
    const from = string(req.body.from, 255);
    const replyTo = string(req.body.reply_to, 255);
    const password = typeof req.body.password === 'string' ? req.body.password.slice(0, 500) : '';
    if (!validMailHost(host)) return res.status(400).json({ message: 'SMTP host must be a hostname or IP address without a protocol.' });
    if (!validMailHost(heloName)) return res.status(400).json({ message: 'HELO name must be a hostname without a protocol.' });
    if (!Number.isInteger(port) || port < 1 || port > 65535) return res.status(400).json({ message: 'SMTP port must be between 1 and 65535.' });
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1000 || timeoutMs > 120000) {
      return res.status(400).json({ message: 'SMTP timeout must be between 1000 and 120000 milliseconds.' });
    }
    if (from && !isEmail(mailboxEmail(from))) return res.status(400).json({ message: 'From address is invalid.' });
    if (replyTo && !isEmail(mailboxEmail(replyTo))) return res.status(400).json({ message: 'Reply-to address is invalid.' });

    let passwordEncrypted = current.password_encrypted || '';
    if (req.body.clear_password === true) passwordEncrypted = '';
    else if (password) passwordEncrypted = encryptSecret(password);
    else if (!passwordEncrypted && config.mail.pass) passwordEncrypted = encryptSecret(config.mail.pass);

    if (enabled && (!host || !from)) {
      return res.status(400).json({ message: 'SMTP host and From address are required when mail is enabled.' });
    }
    if (enabled && authRequired && (!user || !passwordEncrypted)) {
      return res.status(400).json({ message: 'SMTP username and password are required when authentication is enabled.' });
    }

    const stored = {
      configured: true,
      enabled,
      host,
      port,
      secure,
      auth_required: authRequired,
      timeout_ms: timeoutMs,
      helo_name: heloName,
      user,
      password_encrypted: passwordEncrypted,
      from,
      reply_to: replyTo,
    };
    await saveSetting('mail_transport', stored);
    const resolved = await resolveMailConfig();
    res.json({ settings: publicMailSettings(stored, resolved) });
  } catch (error) {
    next(error);
  }
});

router.get('/settings/mail/status', requireOwner, async (_req, res, next) => {
  try {
    const [stored, resolved] = await Promise.all([
      getSetting('mail_transport'),
      resolveMailConfig(),
    ]);
    const settings = publicMailSettings(stored, resolved);
    res.json({
      mail: {
        enabled: settings.ready,
        host_configured: Boolean(settings.host),
        auth_required: settings.auth_required,
        user_configured: Boolean(settings.user),
        password_configured: settings.password_configured,
        from: settings.from,
        source: settings.source,
      },
    });
  } catch (error) {
    next(error);
  }
});

router.post('/settings/mail/test', requireOwner, async (req, res, next) => {
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
