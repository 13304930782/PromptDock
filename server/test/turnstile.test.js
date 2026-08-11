const test = require('node:test');
const assert = require('node:assert/strict');
const { SITEVERIFY_URL, verifyTurnstile } = require('../src/lib/turnstile');

test('posts the canonical Turnstile siteverify request and accepts success true', async () => {
  let request;
  const result = await verifyTurnstile({
    token: 'browser-token',
    remoteIp: '203.0.113.8',
    secret: 'environment-secret',
    fetchImpl: async (url, init) => {
      request = { url, init };
      return {
        ok: true,
        json: async () => ({ success: true }),
      };
    },
  });

  assert.equal(result.success, true);
  assert.equal(request.url, SITEVERIFY_URL);
  assert.equal(request.init.method, 'POST');
  assert.equal(request.init.headers['Content-Type'], 'application/x-www-form-urlencoded');
  assert.equal(request.init.body.get('secret'), 'environment-secret');
  assert.equal(request.init.body.get('response'), 'browser-token');
  assert.equal(request.init.body.get('remoteip'), '203.0.113.8');
});

test('fails closed when Turnstile rejects a token', async () => {
  const result = await verifyTurnstile({
    token: 'invalid-token',
    remoteIp: '203.0.113.8',
    secret: 'environment-secret',
    fetchImpl: async () => ({
      ok: true,
      json: async () => ({ success: false, 'error-codes': ['invalid-input-response'] }),
    }),
  });

  assert.equal(result.success, false);
  assert.equal(result.reason, 'rejected');
  assert.deepEqual(result.errorCodes, ['invalid-input-response']);
});

test('fails closed without a configured secret or browser response', async () => {
  assert.deepEqual(
    await verifyTurnstile({ token: 'token', remoteIp: '203.0.113.8', secret: '' }),
    { success: false, reason: 'missing-secret' },
  );
  assert.deepEqual(
    await verifyTurnstile({ token: '', remoteIp: '203.0.113.8', secret: 'environment-secret' }),
    { success: false, reason: 'missing-response' },
  );
});
