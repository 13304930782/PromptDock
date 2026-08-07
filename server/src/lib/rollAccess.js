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

module.exports = {
  ACCESS_KEY_LIFETIME_MS,
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
};
