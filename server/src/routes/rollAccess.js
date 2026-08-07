const express = require('express');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const db = require('../db');
const config = require('../config');
const { requireAdmin, requireRollKeyIssuer } = require('../middleware/auth');
const { accessKeyExpiry, generateAccessKey, hashAccessKey } = require('../lib/rollAccess');

const publicRouter = express.Router();
const adminRouter = express.Router();
const COOKIE_NAME = `${config.cookie.name}_roll`;

publicRouter.use((_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

adminRouter.use((_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

const verifyLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many access-key attempts. Please try again later.' },
});

function ensureJwtConfigured() {
  if (!config.jwtSecret || config.jwtSecret.length < 32) {
    const error = new Error('JWT_SECRET must contain at least 32 characters.');
    error.code = 'AUTH_NOT_CONFIGURED';
    throw error;
  }
}

function cookieOptions(maxAge) {
  const options = {
    httpOnly: true,
    secure: config.cookie.secure,
    sameSite: 'lax',
    path: '/',
  };
  if (maxAge !== undefined) options.maxAge = maxAge;
  if (config.cookie.domain) options.domain = config.cookie.domain;
  return options;
}

function clearAccessSession(res) {
  res.clearCookie(COOKIE_NAME, cookieOptions());
}

function publicAccessKey(row) {
  return {
    id: row.id,
    key_prefix: row.key_prefix,
    created_by_name: row.created_by_name || null,
    expires_at: row.expires_at,
    revoked_at: row.revoked_at,
    last_used_at: row.last_used_at,
    use_count: Number(row.use_count || 0),
    created_at: row.created_at,
  };
}

publicRouter.post('/verify', verifyLimit, async (req, res, next) => {
  try {
    ensureJwtConfigured();
    const accessKey = String(req.body.access_key || '').trim();
    if (!accessKey || accessKey.length > 128) {
      return res.status(400).json({ message: 'A valid access key is required.' });
    }
    const [rows] = await db.query(
      `SELECT id, expires_at
       FROM roll_access_keys
       WHERE key_hash=? AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP()
       LIMIT 1`,
      [hashAccessKey(accessKey)],
    );
    const record = rows[0];
    if (!record) return res.status(401).json({ message: 'This access key is invalid or expired.' });

    const expiresAt = new Date(record.expires_at);
    const maxAge = Math.max(1, expiresAt.getTime() - Date.now());
    const token = jwt.sign(
      { id: Number(record.id), purpose: 'roll-access' },
      config.jwtSecret,
      { expiresIn: Math.max(1, Math.ceil(maxAge / 1000)) },
    );
    res.cookie(COOKIE_NAME, token, cookieOptions(maxAge));
    await db.query(
      'UPDATE roll_access_keys SET last_used_at=UTC_TIMESTAMP(), use_count=use_count+1 WHERE id=?',
      [record.id],
    );
    return res.json({ expires_at: expiresAt.toISOString() });
  } catch (error) {
    if (error.code === 'AUTH_NOT_CONFIGURED') return res.status(503).json({ message: error.message });
    next(error);
  }
});

publicRouter.get('/session', async (req, res, next) => {
  try {
    ensureJwtConfigured();
    const token = req.cookies?.[COOKIE_NAME];
    if (!token) return res.status(401).json({ message: 'A tool access key is required.' });
    const payload = jwt.verify(token, config.jwtSecret);
    const accessKeyId = Number(payload.id);
    if (payload.purpose !== 'roll-access' || !Number.isInteger(accessKeyId) || accessKeyId < 1) {
      const error = new Error('Invalid access session.');
      error.code = 'INVALID_ROLL_SESSION';
      throw error;
    }
    const [rows] = await db.query(
      `SELECT expires_at
       FROM roll_access_keys
       WHERE id=? AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP()
       LIMIT 1`,
      [accessKeyId],
    );
    if (!rows[0]) {
      clearAccessSession(res);
      return res.status(401).json({ message: 'This access session has expired.' });
    }
    return res.json({ expires_at: new Date(rows[0].expires_at).toISOString() });
  } catch (error) {
    clearAccessSession(res);
    if (error.code === 'AUTH_NOT_CONFIGURED') return res.status(503).json({ message: error.message });
    if (error.code === 'INVALID_ROLL_SESSION' || ['JsonWebTokenError', 'TokenExpiredError', 'NotBeforeError'].includes(error.name)) {
      return res.status(401).json({ message: 'This access session is invalid or expired.' });
    }
    return next(error);
  }
});

publicRouter.post('/logout', (_req, res) => {
  clearAccessSession(res);
  res.json({ message: 'Tool access ended.' });
});

adminRouter.use(requireAdmin, requireRollKeyIssuer);

adminRouter.get('/', async (_req, res, next) => {
  try {
    const [rows] = await db.query(
      `SELECT rak.*, au.name AS created_by_name
       FROM roll_access_keys rak
       LEFT JOIN admin_users au ON au.id=rak.created_by
       ORDER BY rak.id DESC
       LIMIT 100`,
    );
    res.json({ access_keys: rows.map(publicAccessKey) });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/', async (req, res, next) => {
  try {
    const accessKey = generateAccessKey();
    const expiresAt = accessKeyExpiry();
    const [result] = await db.query(
      `INSERT INTO roll_access_keys (key_hash, key_prefix, created_by, expires_at)
       VALUES (?, ?, ?, ?)`,
      [hashAccessKey(accessKey), accessKey.slice(0, 11), req.admin.id, expiresAt],
    );
    const [rows] = await db.query(
      `SELECT rak.*, au.name AS created_by_name
       FROM roll_access_keys rak
       LEFT JOIN admin_users au ON au.id=rak.created_by
       WHERE rak.id=? LIMIT 1`,
      [result.insertId],
    );
    res.status(201).json({ access_key: accessKey, record: publicAccessKey(rows[0]) });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/:id/revoke', async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) return res.status(400).json({ message: 'Access-key id is invalid.' });
    const [result] = await db.query(
      'UPDATE roll_access_keys SET revoked_at=COALESCE(revoked_at, UTC_TIMESTAMP()) WHERE id=?',
      [id],
    );
    if (!result.affectedRows) return res.status(404).json({ message: 'Access key not found.' });
    res.json({ message: 'Access key revoked.' });
  } catch (error) {
    next(error);
  }
});

module.exports = { adminRouter, publicRouter };
