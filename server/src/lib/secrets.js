const crypto = require('crypto');
const config = require('../config');

const VERSION = 'v1';

function encryptionKey(secret = config.jwtSecret) {
  if (!secret || secret.length < 32) {
    throw new Error('JWT_SECRET must contain at least 32 characters before encrypted settings can be used.');
  }
  return crypto.createHash('sha256').update(`cuegrove:settings:${VERSION}:${secret}`).digest();
}

function encryptSecret(value, secret = config.jwtSecret) {
  if (!value) return '';
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey(secret), iv);
  const encrypted = Buffer.concat([cipher.update(String(value), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [VERSION, iv.toString('base64url'), tag.toString('base64url'), encrypted.toString('base64url')].join('.');
}

function decryptSecret(value, secret = config.jwtSecret) {
  if (!value) return '';
  const [version, ivValue, tagValue, encryptedValue] = String(value).split('.');
  if (version !== VERSION || !ivValue || !tagValue || !encryptedValue) {
    throw new Error('Encrypted setting has an unsupported format.');
  }
  try {
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      encryptionKey(secret),
      Buffer.from(ivValue, 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(tagValue, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(encryptedValue, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    throw new Error('Encrypted setting could not be decrypted. Re-enter the secret in administrator settings.');
  }
}

module.exports = { decryptSecret, encryptSecret };
