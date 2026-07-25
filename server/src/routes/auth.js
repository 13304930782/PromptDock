const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const db = require('../db');
const config = require('../config');
const { clearSession, issueSession, publicAdmin, requireAdmin } = require('../middleware/auth');
const { normalizeEmail, passwordError, string } = require('../lib/validation');
const { sendPasswordReset } = require('../lib/mailer');

const router = express.Router();
const MAX_FAILURES = 5;
const LOCK_MINUTES = 15;
const GENERIC_RESET_MESSAGE = 'If that administrator email exists, a reset link will be sent.';

const loginLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many sign-in attempts. Please try again later.' },
});

const resetLimit = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many password reset requests. Please try again later.' },
});

router.post('/login', loginLimit, async (req, res, next) => {
  try {
    const email = normalizeEmail(req.body.email);
    const password = String(req.body.password || '');
    if (!email || !password) return res.status(400).json({ message: 'Email and password are required.' });

    const [rows] = await db.query('SELECT * FROM admin_users WHERE email=? LIMIT 1', [email]);
    const admin = rows[0];
    if (!admin) return res.status(401).json({ message: 'Email or password is incorrect.' });
    if (admin.status !== 'active') return res.status(403).json({ message: 'This administrator account is disabled.' });
    if (admin.locked_until && new Date(admin.locked_until).getTime() > Date.now()) {
      return res.status(423).json({ message: 'This account is temporarily locked. Please try again later.' });
    }

    const matches = await bcrypt.compare(password, admin.password_hash);
    if (!matches) {
      const failures = Number(admin.failed_login_count || 0) + 1;
      if (failures >= MAX_FAILURES) {
        await db.query(
          'UPDATE admin_users SET failed_login_count=?, locked_until=DATE_ADD(NOW(), INTERVAL ? MINUTE) WHERE id=?',
          [failures, LOCK_MINUTES, admin.id],
        );
        return res.status(423).json({ message: 'Too many failed attempts. This account is locked for 15 minutes.' });
      }
      await db.query('UPDATE admin_users SET failed_login_count=?, locked_until=NULL WHERE id=?', [failures, admin.id]);
      return res.status(401).json({ message: 'Email or password is incorrect.' });
    }

    await db.query('UPDATE admin_users SET failed_login_count=0, locked_until=NULL, last_login_at=NOW() WHERE id=?', [admin.id]);
    issueSession(res, admin);
    return res.json({ user: publicAdmin(admin) });
  } catch (error) {
    next(error);
  }
});

router.get('/me', requireAdmin, (req, res) => {
  res.json({ user: publicAdmin(req.admin) });
});

router.post('/logout', (req, res) => {
  clearSession(res);
  res.json({ message: 'Signed out.' });
});

router.post('/forgot-password', resetLimit, async (req, res, next) => {
  try {
    const email = normalizeEmail(req.body.email);
    if (!email) return res.status(400).json({ message: 'Email is required.' });
    const [rows] = await db.query(
      'SELECT id, name, email FROM admin_users WHERE email=? AND status="active" LIMIT 1',
      [email],
    );
    const admin = rows[0];
    if (admin) {
      const token = crypto.randomBytes(32).toString('hex');
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      await db.query('DELETE FROM admin_password_resets WHERE admin_id=? OR expires_at < NOW()', [admin.id]);
      await db.query(
        'INSERT INTO admin_password_resets (admin_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
        [admin.id, tokenHash, config.passwordResetMinutes],
      );
      const delivery = await sendPasswordReset(admin, token);
      if (delivery.status === 'failed') {
        console.error('[auth/forgot-password]', delivery.error);
      }
    }
    res.json({ message: GENERIC_RESET_MESSAGE });
  } catch (error) {
    next(error);
  }
});

router.post('/reset-password', resetLimit, async (req, res, next) => {
  try {
    const token = string(req.body.token, 256);
    const password = String(req.body.password || '');
    const validationError = passwordError(password);
    if (!token) return res.status(400).json({ message: 'Reset token is required.' });
    if (validationError) return res.status(400).json({ message: validationError });

    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const [rows] = await db.query(
      `SELECT pr.id, pr.admin_id
       FROM admin_password_resets pr
       JOIN admin_users au ON au.id=pr.admin_id
       WHERE pr.token_hash=? AND pr.used_at IS NULL AND pr.expires_at > NOW() AND au.status='active'
       LIMIT 1`,
      [tokenHash],
    );
    const reset = rows[0];
    if (!reset) return res.status(400).json({ message: 'This reset link is invalid or expired.' });

    const passwordHash = await bcrypt.hash(password, 12);
    const connection = await db.getConnection();
    try {
      await connection.beginTransaction();
      await connection.query(
        'UPDATE admin_users SET password_hash=?, failed_login_count=0, locked_until=NULL WHERE id=?',
        [passwordHash, reset.admin_id],
      );
      await connection.query('UPDATE admin_password_resets SET used_at=NOW() WHERE id=?', [reset.id]);
      await connection.query('DELETE FROM admin_password_resets WHERE admin_id=? AND id<>?', [reset.admin_id, reset.id]);
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    clearSession(res);
    res.json({ message: 'Password updated. You can now sign in.' });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
