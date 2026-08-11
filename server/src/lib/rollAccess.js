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

function normalizeAccessKeyId(value) {
  if (typeof value === 'number') return Number.isSafeInteger(value) && value > 0 ? value : null;
  if (typeof value !== 'string' || !/^[1-9]\d*$/.test(value)) return null;
  const id = Number(value);
  return Number.isSafeInteger(id) ? id : null;
}

function normalizeAccessKeyIds(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 100) return null;
  const ids = value.map(normalizeAccessKeyId);
  return ids.includes(null) ? null : [...new Set(ids)];
}

function rollAccessIdFromPayload(payload) {
  const id = Number(payload.id);
  return payload.purpose === 'roll-access' && Number.isSafeInteger(id) && id > 0 ? id : null;
}

module.exports = {
  ACCESS_KEY_LIFETIME_MS,
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
  normalizeAccessKeyId,
  normalizeAccessKeyIds,
  rollAccessIdFromPayload,
};
