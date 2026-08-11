const test = require('node:test');
const assert = require('node:assert/strict');
const {
  base32Decode,
  base32Encode,
  findRecoveryCodeIndex,
  generateRecoveryCodes,
  hashRecoveryCode,
  matchingTotpStep,
  normalizeRecoveryCode,
  totpAt,
} = require('../src/lib/mfa');

test('Base32 encoding round-trips binary secrets', () => {
  const source = Buffer.from('CueGrove MFA secret', 'utf8');
  assert.deepEqual(base32Decode(base32Encode(source)), source);
});

test('TOTP implementation matches the RFC 6238 SHA-1 vector', () => {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  assert.equal(totpAt(secret, 59_000, { digits: 8 }), '94287082');
});

test('TOTP verification accepts a small clock window and rejects replay', () => {
  const secret = base32Encode(Buffer.from('12345678901234567890'));
  const timeMs = 1_700_000_000_000;
  const previousCode = totpAt(secret, timeMs - 30_000);
  const matchedStep = matchingTotpStep(secret, previousCode, { timeMs, window: 1 });

  assert.equal(matchedStep, Math.floor((timeMs - 30_000) / 1000 / 30));
  assert.equal(
    matchingTotpStep(secret, previousCode, { timeMs, window: 1, lastUsedStep: matchedStep }),
    null,
  );
  assert.equal(matchingTotpStep(secret, '00000x', { timeMs }), null);
});

test('Recovery codes are normalized, hashed, and individually consumable', () => {
  const codes = generateRecoveryCodes(10);
  assert.equal(codes.length, 10);
  assert.equal(new Set(codes).size, 10);
  const hashes = codes.map(hashRecoveryCode);
  const typedWithoutDashes = normalizeRecoveryCode(codes[3]).toLowerCase();

  assert.equal(findRecoveryCodeIndex(hashes, typedWithoutDashes), 3);
  hashes.splice(3, 1);
  assert.equal(findRecoveryCodeIndex(hashes, typedWithoutDashes), -1);
});
