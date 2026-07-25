const express = require('express');
const rateLimit = require('express-rate-limit');
const db = require('../db');
const { getSetting } = require('../lib/settings');
const { sendNewApplicationNotification } = require('../lib/mailer');
const { validateApplication } = require('../lib/validation');

const router = express.Router();
const GENERIC_MESSAGE = 'Thanks. Your application has been received and will be reviewed.';

const submissionLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 6,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many applications were submitted from this connection. Please try again later.' },
});

router.post('/applications', submissionLimit, async (req, res, next) => {
  try {
    const result = validateApplication(req.body);
    if (!result.ok) {
      if (result.silent) return res.status(202).json({ message: GENERIC_MESSAGE });
      return res.status(400).json({ message: result.message });
    }

    const settings = await getSetting('early_access');
    if (!settings.applications_open) {
      return res.status(409).json({ message: 'PromptDock Early Access applications are currently closed.' });
    }

    const value = result.value;
    const [insert] = await db.query(
      `INSERT IGNORE INTO early_access_applications
       (full_name, email, role, use_case, motivation, locale, cohort, consented_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
      [value.fullName, value.email, value.role, value.useCase, value.motivation, value.locale, settings.cohort],
    );

    if (insert.affectedRows === 1) {
      const [rows] = await db.query(
        'SELECT * FROM early_access_applications WHERE id=? LIMIT 1',
        [insert.insertId],
      );
      const application = rows[0];
      setImmediate(() => {
        sendNewApplicationNotification(application, settings).catch((error) => {
          console.error('[early-access/notify]', error.message);
        });
      });
    }

    return res.status(202).json({ message: GENERIC_MESSAGE });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
