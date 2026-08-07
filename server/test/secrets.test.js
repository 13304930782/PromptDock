const test = require('node:test');
const assert = require('node:assert/strict');
const { decryptSecret, encryptSecret } = require('../src/lib/secrets');

const key = 'cuegrove-test-secret-that-is-longer-than-thirty-two-characters';

test('encrypts and decrypts stored administrator secrets', () => {
  const encrypted = encryptSecret('smtp-password-123', key);
  assert.doesNotMatch(encrypted, /smtp-password-123/);
  assert.equal(decryptSecret(encrypted, key), 'smtp-password-123');
});

test('rejects encrypted settings modified after saving', () => {
  const encrypted = encryptSecret('smtp-password-123', key);
  assert.throws(() => decryptSecret(`${encrypted}changed`, key), /could not be decrypted/);
});
