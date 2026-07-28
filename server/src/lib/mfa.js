const crypto = require('crypto');

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const RECOVERY_CODE_GROUPS = 5;

function base32Encode(value) {
  const bytes = Buffer.isBuffer(value) ? value : Buffer.from(value);
  let bits = 0;
  let buffer = 0;
  let output = '';

  for (const byte of bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += BASE32_ALPHABET[(buffer >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }

  if (bits > 0) output += BASE32_ALPHABET[(buffer << (5 - bits)) & 31];
  return output;
}

function base32Decode(value) {
  const input = String(value || '').toUpperCase().replace(/=+$/g, '').replace(/\s+/g, '');
  let bits = 0;
  let buffer = 0;
  const output = [];

  for (const character of input) {
    const index = BASE32_ALPHABET.indexOf(character);
    if (index < 0) throw new Error('TOTP secret contains invalid Base32 characters.');
    buffer = (buffer << 5) | index;
    bits += 5;
    if (bits >= 8) {
      output.push((buffer >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }

  return Buffer.from(output);
}

function generateTotpSecret(bytes = 20) {
  return base32Encode(crypto.randomBytes(bytes));
}

function hotp(secret, counter, { digits = 6, algorithm = 'sha1' } = {}) {
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac(algorithm, base32Decode(secret)).update(counterBuffer).digest();
  const offset = digest[digest.length - 1] & 15;
  const binary = (
    ((digest[offset] & 127) << 24)
    | ((digest[offset + 1] & 255) << 16)
    | ((digest[offset + 2] & 255) << 8)
    | (digest[offset + 3] & 255)
  );
  return String(binary % (10 ** digits)).padStart(digits, '0');
}

function totpAt(secret, timeMs = Date.now(), options = {}) {
  const period = options.period || 30;
  const step = Math.floor(timeMs / 1000 / period);
  return hotp(secret, step, options);
}

function safeCodeEqual(expected, received) {
  const left = Buffer.from(String(expected));
  const right = Buffer.from(String(received));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function matchingTotpStep(secret, token, {
  timeMs = Date.now(),
  window = 1,
  period = 30,
  digits = 6,
  algorithm = 'sha1',
  lastUsedStep = null,
} = {}) {
  const normalized = String(token || '').replace(/\s+/g, '');
  if (!new RegExp(`^\\d{${digits}}$`).test(normalized)) return null;
  const currentStep = Math.floor(timeMs / 1000 / period);
  for (let offset = -window; offset <= window; offset += 1) {
    const step = currentStep + offset;
    if (lastUsedStep !== null && step <= Number(lastUsedStep)) continue;
    if (safeCodeEqual(hotp(secret, step, { digits, algorithm }), normalized)) return step;
  }
  return null;
}

function buildOtpAuthUri({ secret, email, issuer = 'CueGrove' }) {
  const label = encodeURIComponent(`${issuer}:${email}`);
  const parameters = new URLSearchParams({
    secret,
    issuer,
    algorithm: 'SHA1',
    digits: '6',
    period: '30',
  });
  return `otpauth://totp/${label}?${parameters.toString()}`;
}

function normalizeRecoveryCode(value) {
  return String(value || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function generateRecoveryCodes(count = 10) {
  return Array.from({ length: count }, () => {
    const compact = crypto.randomBytes(10).toString('hex').toUpperCase();
    return compact.match(new RegExp(`.{1,4}`, 'g')).slice(0, RECOVERY_CODE_GROUPS).join('-');
  });
}

function hashRecoveryCode(value) {
  return crypto.createHash('sha256').update(normalizeRecoveryCode(value)).digest('hex');
}

function parseRecoveryHashes(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.filter((item) => typeof item === 'string');
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter((item) => typeof item === 'string') : [];
  } catch {
    return [];
  }
}

function findRecoveryCodeIndex(hashes, value) {
  const candidate = hashRecoveryCode(value);
  return hashes.findIndex((stored) => safeCodeEqual(stored, candidate));
}

module.exports = {
  base32Decode,
  base32Encode,
  buildOtpAuthUri,
  findRecoveryCodeIndex,
  generateRecoveryCodes,
  generateTotpSecret,
  hashRecoveryCode,
  matchingTotpStep,
  normalizeRecoveryCode,
  parseRecoveryHashes,
  totpAt,
};
