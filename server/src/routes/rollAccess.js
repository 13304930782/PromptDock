const express = require('express');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const { randomUUID } = require('crypto');
const db = require('../db');
const config = require('../config');
const { optionalAdminSession, requireAdmin, requireRollKeyIssuer } = require('../middleware/auth');
const {
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
  normalizeAccessKeyId,
  normalizeAccessKeyIds,
  rollAccessIdFromPayload,
} = require('../lib/rollAccess');

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

async function inTransaction(work) {
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    const result = await work(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback().catch(() => undefined);
    throw error;
  } finally {
    connection.release();
  }
}

async function recordKeyAudit(connection, entries) {
  if (!entries.length) return;
  const placeholders = entries.map(() => '(?, ?, ?, ?, ?)').join(',');
  const values = entries.flatMap((entry) => [
    entry.keyId,
    entry.keyPrefix,
    entry.adminId,
    entry.action,
    entry.batchId || null,
  ]);
  await connection.query(
    `INSERT INTO roll_access_key_audit (key_id, key_prefix, admin_id, action, batch_id)
     VALUES ${placeholders}`,
    values,
  );
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
    return res.json({ administrator: false, expires_at: expiresAt.toISOString() });
  } catch (error) {
    if (error.code === 'AUTH_NOT_CONFIGURED') return res.status(503).json({ message: error.message });
    next(error);
  }
});

publicRouter.get('/session', async (req, res, next) => {
  try {
    ensureJwtConfigured();
    const admin = await optionalAdminSession(req);
    if (admin) return res.json({ administrator: true, expires_at: null });
    const token = req.cookies?.[COOKIE_NAME];
    if (!token) return res.status(401).json({ message: 'A tool access key is required.' });
    const payload = jwt.verify(token, config.jwtSecret);
    const accessKeyId = rollAccessIdFromPayload(payload);
    if (!accessKeyId) {
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
    return res.json({ administrator: false, expires_at: new Date(rows[0].expires_at).toISOString() });
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
    const keyPrefix = accessKey.slice(0, 11);
    const record = await inTransaction(async (connection) => {
      const [result] = await connection.query(
        `INSERT INTO roll_access_keys (key_hash, key_prefix, created_by, expires_at)
         VALUES (?, ?, ?, ?)`,
        [hashAccessKey(accessKey), keyPrefix, req.admin.id, expiresAt],
      );
      await recordKeyAudit(connection, [{
        keyId: result.insertId,
        keyPrefix,
        adminId: req.admin.id,
        action: 'create',
      }]);
      const [rows] = await connection.query(
        `SELECT rak.*, au.name AS created_by_name
         FROM roll_access_keys rak
         LEFT JOIN admin_users au ON au.id=rak.created_by
         WHERE rak.id=? LIMIT 1`,
        [result.insertId],
      );
      return rows[0];
    });
    res.status(201).json({ access_key: accessKey, record: publicAccessKey(record) });
  } catch (error) {
    next(error);
  }
});

adminRouter.post('/:id/revoke', async (req, res, next) => {
  try {
    const id = normalizeAccessKeyId(req.params.id);
    if (!id) return res.status(400).json({ message: 'Access-key id is invalid.' });
    const revoked = await inTransaction(async (connection) => {
      const [rows] = await connection.query(
        'SELECT id, key_prefix FROM roll_access_keys WHERE id=? AND revoked_at IS NULL FOR UPDATE',
        [id],
      );
      if (!rows[0]) return false;
      await connection.query('UPDATE roll_access_keys SET revoked_at=UTC_TIMESTAMP() WHERE id=?', [id]);
      await recordKeyAudit(connection, [{
        keyId: id,
        keyPrefix: rows[0].key_prefix,
        adminId: req.admin.id,
        action: 'revoke',
      }]);
      return true;
    });
    if (!revoked) return res.status(404).json({ message: 'Access key not found or already revoked.' });
    res.json({ message: 'Access key revoked.' });
  } catch (error) {
    next(error);
  }
});

adminRouter.delete('/', async (req, res, next) => {
  try {
    const ids = normalizeAccessKeyIds(req.body.ids);
    if (!ids) return res.status(400).json({ message: 'Select between 1 and 100 valid access keys.' });
    const placeholders = ids.map(() => '?').join(',');
    const deleted = await inTransaction(async (connection) => {
      const [rows] = await connection.query(
        `SELECT id, key_prefix FROM roll_access_keys WHERE id IN (${placeholders}) FOR UPDATE`,
        ids,
      );
      if (!rows.length) return 0;
      const batchId = randomUUID();
      await recordKeyAudit(connection, rows.map((row) => ({
        keyId: row.id,
        keyPrefix: row.key_prefix,
        adminId: req.admin.id,
        action: 'bulk_delete',
        batchId,
      })));
      const rowIds = rows.map((row) => row.id);
      const rowPlaceholders = rowIds.map(() => '?').join(',');
      const [result] = await connection.query(`DELETE FROM roll_access_keys WHERE id IN (${rowPlaceholders})`, rowIds);
      return result.affectedRows;
    });
    res.json({ deleted });
  } catch (error) {
    next(error);
  }
});

adminRouter.delete('/:id', async (req, res, next) => {
  try {
    const id = normalizeAccessKeyId(req.params.id);
    if (!id) return res.status(400).json({ message: 'Access-key id is invalid.' });
    const deleted = await inTransaction(async (connection) => {
      const [rows] = await connection.query(
        'SELECT id, key_prefix FROM roll_access_keys WHERE id=? FOR UPDATE',
        [id],
      );
      if (!rows[0]) return false;
      await recordKeyAudit(connection, [{
        keyId: id,
        keyPrefix: rows[0].key_prefix,
        adminId: req.admin.id,
        action: 'delete',
      }]);
      await connection.query('DELETE FROM roll_access_keys WHERE id=?', [id]);
      return true;
    });
    if (!deleted) return res.status(404).json({ message: 'Access key not found.' });
    res.json({ deleted: 1 });
  } catch (error) {
    next(error);
  }
});

module.exports = { adminRouter, publicRouter };
