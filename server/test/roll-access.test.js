const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ACCESS_KEY_LIFETIME_MS,
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
} = require('../src/lib/rollAccess');
const { requireRollKeyIssuer } = require('../src/middleware/auth');

test('creates a strong access key and stores only its stable hash', () => {
  const key = generateAccessKey((size) => Buffer.alloc(size, 7));
  assert.match(key, /^CG-[A-Za-z0-9_-]{24}$/);
  assert.equal(hashAccessKey(` ${key} `), hashAccessKey(key));
  assert.notEqual(hashAccessKey(key), key);
});

test('temporary tool access expires exactly 24 hours after creation', () => {
  const now = Date.UTC(2026, 7, 8, 12, 0, 0);
  assert.equal(accessKeyExpiry(now).getTime() - now, ACCESS_KEY_LIFETIME_MS);
  assert.equal(ACCESS_KEY_LIFETIME_MS, 24 * 60 * 60 * 1000);
});

test('only owners and the designated administrator may issue tool keys', () => {
  let nextCalls = 0;
  const next = () => { nextCalls += 1; };
  const response = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };

  requireRollKeyIssuer({ admin: { role: 'owner', can_issue_roll_keys: false } }, response, next);
  requireRollKeyIssuer({ admin: { role: 'admin', can_issue_roll_keys: true } }, response, next);
  requireRollKeyIssuer({ admin: { role: 'admin', can_issue_roll_keys: false } }, response, next);

  assert.equal(nextCalls, 2);
  assert.equal(response.statusCode, 403);
  assert.match(response.body.message, /permission/i);
});
