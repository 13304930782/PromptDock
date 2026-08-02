const crypto = require('crypto');
const express = require('express');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const QRCode = require('qrcode');
const db = require('../db');
const config = require('../config');
const { clearSession, issueSession, publicAdmin, requireAdmin } = require('../middleware/auth');
const {
  buildOtpAuthUri,
  findRecoveryCodeIndex,
  generateRecoveryCodes,
  generateTotpSecret,
  hashRecoveryCode,
  matchingTotpStep,
  parseRecoveryHashes,
} = require('../lib/mfa');
const { decryptSecret, encryptSecret } = require('../lib/secrets');
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

const mfaLimit = rateLimit({
  windowMs: 10 * 60 * 1000,
  limit: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many verification attempts. Please try again later.' },
});

function createMfaChallenge(admin) {
  if (!config.jwtSecret || config.jwtSecret.length < 32) {
    const error = new Error('JWT_SECRET must contain at least 32 characters.');
    error.code = 'AUTH_NOT_CONFIGURED';
    throw error;
  }
  return jwt.sign(
    {
      id: admin.id,
      purpose: 'mfa-login',
      token_version: Number(admin.token_version || 0),
    },
    config.jwtSecret,
    { expiresIn: '5m' },
  );
}

function verifyMfaChallenge(token) {
  const payload = jwt.verify(String(token || ''), config.jwtSecret);
  if (payload.purpose !== 'mfa-login' || !Number.isInteger(Number(payload.id))) {
    throw new Error('Invalid MFA challenge.');
  }
  return {
    id: Number(payload.id),
    tokenVersion: Number(payload.token_version),
  };
}

function verifySecondFactor(admin, code, { allowRecovery = true, requireTotp = false } = {}) {
  if (!admin.mfa_secret_encrypted || !admin.mfa_enabled_at) return { ok: false };
  const secret = decryptSecret(admin.mfa_secret_encrypted);
  const step = matchingTotpStep(secret, code, {
    lastUsedStep: admin.mfa_last_used_step === null ? null : Number(admin.mfa_last_used_step),
  });
  if (step !== null) return { ok: true, type: 'totp', step };
  if (!allowRecovery || requireTotp) return { ok: false };

  const hashes = parseRecoveryHashes(admin.mfa_recovery_hashes);
  const recoveryIndex = findRecoveryCodeIndex(hashes, code);
  if (recoveryIndex < 0) return { ok: false };
  hashes.splice(recoveryIndex, 1);
  return { ok: true, type: 'recovery', recoveryHashes: hashes };
}

async function recordSecondFactorUse(connection, adminId, verification) {
  if (verification.type === 'totp') {
    await connection.query('UPDATE admin_users SET mfa_last_used_step=? WHERE id=?', [verification.step, adminId]);
  } else {
    await connection.query(
      'UPDATE admin_users SET mfa_recovery_hashes=? WHERE id=?',
      [JSON.stringify(verification.recoveryHashes), adminId],
    );
  }
}

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

    if (admin.mfa_enabled_at) {
      if (!admin.mfa_secret_encrypted) {
        return res.status(503).json({ message: 'Multi-factor authentication is not configured correctly for this account.' });
      }
      return res.json({
        mfa_required: true,
        challenge_token: createMfaChallenge(admin),
      });
    }

    await db.query(
      'UPDATE admin_users SET failed_login_count=0, locked_until=NULL, last_login_at=NOW() WHERE id=?',
      [admin.id],
    );
    issueSession(res, admin);
    return res.json({ user: publicAdmin(admin) });
  } catch (error) {
    next(error);
  }
});

router.post('/mfa/verify-login', mfaLimit, async (req, res, next) => {
  let connection;
  try {
    let challenge;
    try {
      challenge = verifyMfaChallenge(req.body.challenge_token);
    } catch {
      return res.status(401).json({ message: 'This verification request is invalid or expired. Sign in again.' });
    }
    const code = string(req.body.code, 80);
    if (!code) return res.status(400).json({ message: 'Authenticator or recovery code is required.' });

    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query('SELECT * FROM admin_users WHERE id=? FOR UPDATE', [challenge.id]);
    const admin = rows[0];
    if (
      !admin
      || admin.status !== 'active'
      || challenge.tokenVersion !== Number(admin.token_version)
    ) {
      await connection.rollback();
      return res.status(401).json({ message: 'This verification request is no longer valid.' });
    }
    if (admin.locked_until && new Date(admin.locked_until).getTime() > Date.now()) {
      await connection.rollback();
      return res.status(423).json({ message: 'This account is temporarily locked. Please try again later.' });
    }
    const verification = verifySecondFactor(admin, code);
    if (!verification.ok) {
      const failures = Number(admin.failed_login_count || 0) + 1;
      await connection.query(
        `UPDATE admin_users
         SET failed_login_count=?,
             locked_until=IF(? >= ?, DATE_ADD(NOW(), INTERVAL ? MINUTE), NULL)
         WHERE id=?`,
        [failures, failures, MAX_FAILURES, LOCK_MINUTES, admin.id],
      );
      await connection.commit();
      if (failures >= MAX_FAILURES) {
        return res.status(423).json({ message: 'Too many failed attempts. This account is locked for 15 minutes.' });
      }
      return res.status(401).json({ message: 'Authenticator or recovery code is incorrect.' });
    }
    await recordSecondFactorUse(connection, admin.id, verification);
    await connection.query(
      'UPDATE admin_users SET failed_login_count=0, locked_until=NULL, last_login_at=NOW() WHERE id=?',
      [admin.id],
    );
    await connection.commit();
    issueSession(res, admin);
    return res.json({
      user: publicAdmin(admin),
      recovery_code_used: verification.type === 'recovery',
      recovery_codes_remaining: verification.type === 'recovery' ? verification.recoveryHashes.length : undefined,
    });
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    next(error);
  } finally {
    if (connection) connection.release();
  }
});

router.get('/mfa/status', requireAdmin, async (req, res, next) => {
  try {
    const [rows] = await db.query(
      'SELECT mfa_enabled_at, mfa_recovery_hashes FROM admin_users WHERE id=? LIMIT 1',
      [req.admin.id],
    );
    const admin = rows[0];
    res.json({
      enabled: Boolean(admin?.mfa_enabled_at),
      enabled_at: admin?.mfa_enabled_at || null,
      recovery_codes_remaining: parseRecoveryHashes(admin?.mfa_recovery_hashes).length,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/mfa/setup', requireAdmin, mfaLimit, async (req, res, next) => {
  try {
    const [rows] = await db.query('SELECT mfa_enabled_at FROM admin_users WHERE id=? LIMIT 1', [req.admin.id]);
    if (rows[0]?.mfa_enabled_at) {
      return res.status(409).json({ message: 'Multi-factor authentication is already enabled.' });
    }
    const secret = generateTotpSecret();
    const otpauthUri = buildOtpAuthUri({ secret, email: req.admin.email });
    const qrDataUrl = await QRCode.toDataURL(otpauthUri, {
      errorCorrectionLevel: 'M',
      margin: 2,
      width: 280,
      color: { dark: '#0b503f', light: '#fffdf7' },
    });
    await db.query(
      `UPDATE admin_users
       SET mfa_secret_encrypted=?, mfa_setup_expires_at=DATE_ADD(NOW(), INTERVAL 15 MINUTE),
           mfa_recovery_hashes=NULL, mfa_last_used_step=NULL
       WHERE id=?`,
      [encryptSecret(secret), req.admin.id],
    );
    return res.json({
      secret,
      otpauth_uri: otpauthUri,
      qr_data_url: qrDataUrl,
      expires_in_minutes: 15,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/mfa/enable', requireAdmin, mfaLimit, async (req, res, next) => {
  let connection;
  try {
    const code = string(req.body.code, 20);
    if (!code) return res.status(400).json({ message: 'Authenticator code is required.' });
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query('SELECT * FROM admin_users WHERE id=? FOR UPDATE', [req.admin.id]);
    const admin = rows[0];
    if (admin.mfa_enabled_at) {
      await connection.rollback();
      return res.status(409).json({ message: 'Multi-factor authentication is already enabled.' });
    }
    if (
      !admin.mfa_secret_encrypted
      || !admin.mfa_setup_expires_at
      || new Date(admin.mfa_setup_expires_at).getTime() <= Date.now()
    ) {
      await connection.rollback();
      return res.status(400).json({ message: 'This setup expired. Start multi-factor authentication setup again.' });
    }
    const secret = decryptSecret(admin.mfa_secret_encrypted);
    const step = matchingTotpStep(secret, code);
    if (step === null) {
      await connection.rollback();
      return res.status(401).json({ message: 'Authenticator code is incorrect.' });
    }
    const recoveryCodes = generateRecoveryCodes();
    await connection.query(
      `UPDATE admin_users
       SET mfa_enabled_at=NOW(), mfa_setup_expires_at=NULL, mfa_last_used_step=?,
           mfa_recovery_hashes=?, token_version=token_version+1
       WHERE id=?`,
      [step, JSON.stringify(recoveryCodes.map(hashRecoveryCode)), admin.id],
    );
    await connection.commit();
    const updatedAdmin = {
      ...admin,
      mfa_enabled_at: new Date(),
      token_version: Number(admin.token_version || 0) + 1,
    };
    issueSession(res, updatedAdmin);
    return res.json({
      user: publicAdmin(updatedAdmin),
      recovery_codes: recoveryCodes,
    });
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    next(error);
  } finally {
    if (connection) connection.release();
  }
});

router.post('/mfa/recovery-codes', requireAdmin, mfaLimit, async (req, res, next) => {
  let connection;
  try {
    const code = string(req.body.code, 20);
    if (!code) return res.status(400).json({ message: 'Current authenticator code is required.' });
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query('SELECT * FROM admin_users WHERE id=? FOR UPDATE', [req.admin.id]);
    const admin = rows[0];
    const verification = verifySecondFactor(admin, code, { allowRecovery: false, requireTotp: true });
    if (!verification.ok) {
      await connection.rollback();
      return res.status(401).json({ message: 'Authenticator code is incorrect.' });
    }
    const recoveryCodes = generateRecoveryCodes();
    await connection.query(
      'UPDATE admin_users SET mfa_last_used_step=?, mfa_recovery_hashes=? WHERE id=?',
      [verification.step, JSON.stringify(recoveryCodes.map(hashRecoveryCode)), admin.id],
    );
    await connection.commit();
    return res.json({ recovery_codes: recoveryCodes });
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    next(error);
  } finally {
    if (connection) connection.release();
  }
});

router.delete('/mfa', requireAdmin, mfaLimit, async (req, res, next) => {
  let connection;
  try {
    const password = String(req.body.password || '');
    const code = string(req.body.code, 80);
    if (!password || !code) {
      return res.status(400).json({ message: 'Current password and authenticator or recovery code are required.' });
    }
    connection = await db.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.query('SELECT * FROM admin_users WHERE id=? FOR UPDATE', [req.admin.id]);
    const admin = rows[0];
    if (!admin?.mfa_enabled_at) {
      await connection.rollback();
      return res.status(409).json({ message: 'Multi-factor authentication is not enabled.' });
    }
    const passwordMatches = await bcrypt.compare(password, admin.password_hash);
    if (!passwordMatches) {
      await connection.rollback();
      return res.status(401).json({ message: 'Current password is incorrect.' });
    }
    const verification = verifySecondFactor(admin, code);
    if (!verification.ok) {
      await connection.rollback();
      return res.status(401).json({ message: 'Authenticator or recovery code is incorrect.' });
    }
    await connection.query(
      `UPDATE admin_users
       SET mfa_secret_encrypted=NULL, mfa_setup_expires_at=NULL, mfa_enabled_at=NULL,
           mfa_recovery_hashes=NULL, mfa_last_used_step=NULL,
           token_version=token_version+1
       WHERE id=?`,
      [admin.id],
    );
    await connection.commit();
    const updatedAdmin = {
      ...admin,
      mfa_enabled_at: null,
      token_version: Number(admin.token_version || 0) + 1,
    };
    issueSession(res, updatedAdmin);
    return res.json({ user: publicAdmin(updatedAdmin) });
  } catch (error) {
    if (connection) await connection.rollback().catch(() => undefined);
    next(error);
  } finally {
    if (connection) connection.release();
  }
});

router.get('/me', requireAdmin, (req, res) => {
  res.json({ user: publicAdmin(req.admin) });
});

router.post('/logout', requireAdmin, async (req, res, next) => {
  try {
    await db.query(
      'UPDATE admin_users SET token_version=token_version+1 WHERE id=?',
      [req.admin.id],
    );
    clearSession(res);
    res.json({ message: 'Signed out.' });
  } catch (error) {
    next(error);
  }
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
        `UPDATE admin_users
         SET password_hash=?, failed_login_count=0, locked_until=NULL,
             token_version=token_version+1
         WHERE id=?`,
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
