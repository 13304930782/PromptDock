const crypto = require('crypto');

const ACCESS_KEY_LIFETIME_MS = 24 * 60 * 60 * 1000;

function generateAccessKey(randomBytes = crypto.randomBytes) {
  return `CG-${randomBytes(18).toString('base64url')}`;
}

function hashAccessKey(value) {
  return crypto.createHash('sha256').update(String(value || '').trim()).digest('hex');
}

function accessKeyExpiry(now = Date.now()) {
  return new Date(now + ACCESS_KEY_LIFETIME_MS);
}

function normalizeAccessKeyIds(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 100) return null;
  const ids = [...new Set(value.map(Number))];
  return ids.every((id) => Number.isInteger(id) && id > 0) ? ids : null;
}

module.exports = {
  ACCESS_KEY_LIFETIME_MS,
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
  normalizeAccessKeyIds,
};
