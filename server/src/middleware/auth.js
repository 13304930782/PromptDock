const jwt = require('jsonwebtoken');
const db = require('../db');
const config = require('../config');

const COOKIE_MAX_AGE = 7 * 24 * 60 * 60 * 1000;

function ensureJwtConfigured() {
  if (!config.jwtSecret || config.jwtSecret.length < 32) {
    const error = new Error('JWT_SECRET must contain at least 32 characters.');
    error.code = 'AUTH_NOT_CONFIGURED';
    throw error;
  }
}

function cookieOptions() {
  const options = {
    httpOnly: true,
    secure: config.cookie.secure,
    sameSite: 'lax',
    path: '/',
    maxAge: COOKIE_MAX_AGE,
  };
  if (config.cookie.domain) options.domain = config.cookie.domain;
  return options;
}

function publicAdmin(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    can_issue_roll_keys: Boolean(user.can_issue_roll_keys),
    mfa_enabled: Boolean(user.mfa_enabled_at),
  };
}

function issueSession(res, user) {
  ensureJwtConfigured();
  const token = jwt.sign({ id: user.id, purpose: 'admin' }, config.jwtSecret, { expiresIn: '7d' });
  res.cookie(config.cookie.name, token, cookieOptions());
}

function adminIdFromPayload(payload) {
  const id = Number(payload.id);
  return payload.purpose === 'admin' && Number.isSafeInteger(id) && id > 0 ? id : null;
}

function clearSession(res) {
  const options = cookieOptions();
  delete options.maxAge;
  res.clearCookie(config.cookie.name, options);
}

async function requireAdmin(req, res, next) {
  try {
    ensureJwtConfigured();
    const token = req.cookies?.[config.cookie.name];
    if (!token) return res.status(401).json({ message: 'Administrator sign-in is required.' });
    const payload = jwt.verify(token, config.jwtSecret);
    const adminId = adminIdFromPayload(payload);
    if (!adminId) return res.status(401).json({ message: 'Administrator session is invalid.' });
    const [rows] = await db.query(
      'SELECT id, name, email, role, status, can_issue_roll_keys, mfa_enabled_at FROM admin_users WHERE id=? LIMIT 1',
      [adminId],
    );
    const admin = rows[0];
    if (!admin) return res.status(401).json({ message: 'Administrator session is no longer valid.' });
    if (admin.status !== 'active') return res.status(403).json({ message: 'This administrator account is disabled.' });
    if (!['owner', 'admin'].includes(admin.role)) return res.status(403).json({ message: 'Administrator permission is required.' });
    req.admin = admin;
    next();
  } catch (error) {
    if (error.code === 'AUTH_NOT_CONFIGURED') return res.status(503).json({ message: error.message });
    return res.status(401).json({ message: 'Administrator session expired. Please sign in again.' });
  }
}

async function optionalAdminSession(req) {
  ensureJwtConfigured();
  const token = req.cookies?.[config.cookie.name];
  if (!token) return null;
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch {
    return null;
  }
  const adminId = adminIdFromPayload(payload);
  if (!adminId) return null;
  const [rows] = await db.query(
    'SELECT id, name, email, role, status, can_issue_roll_keys, mfa_enabled_at FROM admin_users WHERE id=? LIMIT 1',
    [adminId],
  );
  const admin = rows[0];
  return admin?.status === 'active' && ['owner', 'admin'].includes(admin.role) ? admin : null;
}

function requireOwner(req, res, next) {
  if (req.admin?.role !== 'owner') {
    return res.status(403).json({ message: 'Owner permission is required for this action.' });
  }
  next();
}

function requireRollKeyIssuer(req, res, next) {
  if (req.admin?.role !== 'owner' && !req.admin?.can_issue_roll_keys) {
    return res.status(403).json({ message: 'Tool access-key permission is required for this action.' });
  }
  next();
}

module.exports = {
  clearSession,
  issueSession,
  publicAdmin,
  optionalAdminSession,
  requireAdmin,
  requireOwner,
  requireRollKeyIssuer,
};
