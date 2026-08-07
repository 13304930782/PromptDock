const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const db = require('../src/db');
const config = require('../src/config');
const {
  ACCESS_KEY_LIFETIME_MS,
  accessKeyExpiry,
  generateAccessKey,
  hashAccessKey,
  normalizeAccessKeyId,
  normalizeAccessKeyIds,
  rollAccessIdFromPayload,
} = require('../src/lib/rollAccess');
const { issueSession, optionalAdminSession, requireAdmin, requireRollKeyIssuer } = require('../src/middleware/auth');

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

test('normalizes unique access-key ids for bulk deletion', () => {
  assert.deepEqual(normalizeAccessKeyIds([3, '2', 3]), [3, 2]);
  assert.equal(normalizeAccessKeyIds([]), null);
  assert.equal(normalizeAccessKeyIds([1, 0]), null);
  assert.equal(normalizeAccessKeyIds(Array.from({ length: 101 }, (_, index) => index + 1)), null);
  for (const invalid of [true, false, null, '1e3', '0x10', '', 1.5, -1, 0, '9007199254740992']) {
    assert.equal(normalizeAccessKeyIds([invalid]), null, `accepted invalid id: ${String(invalid)}`);
  }
});

test('accepts only positive decimal access-key ids', () => {
  assert.equal(normalizeAccessKeyId(12), 12);
  assert.equal(normalizeAccessKeyId('12'), 12);
  for (const invalid of [true, null, '1e3', '0x10', '01', '', 1.5, -1, 0, '9007199254740992']) {
    assert.equal(normalizeAccessKeyId(invalid), null, `accepted invalid id: ${String(invalid)}`);
  }
});

test('accepts only roll-access JWT payloads for tool sessions', () => {
  assert.equal(rollAccessIdFromPayload({ id: 4, purpose: 'roll-access' }), 4);
  assert.equal(rollAccessIdFromPayload({ id: 4, purpose: 'admin' }), null);
  assert.equal(rollAccessIdFromPayload({ id: 4, purpose: 'mfa-login' }), null);
  assert.equal(rollAccessIdFromPayload({ id: Number.MAX_SAFE_INTEGER + 1, purpose: 'roll-access' }), null);
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

test('an active administrator session bypasses the temporary tool key', async (t) => {
  const originalSecret = config.jwtSecret;
  const originalQuery = db.query;
  config.jwtSecret = 'test-secret-that-is-at-least-32-characters';
  db.query = async () => [[{
    id: 7,
    name: 'Site Admin',
    email: 'admin@example.com',
    role: 'admin',
    status: 'active',
    can_issue_roll_keys: 0,
    mfa_enabled_at: null,
  }]];
  t.after(() => {
    config.jwtSecret = originalSecret;
    db.query = originalQuery;
  });

  const token = jwt.sign({ id: 7, purpose: 'admin' }, config.jwtSecret, { expiresIn: '5m' });
  const admin = await optionalAdminSession({ cookies: { [config.cookie.name]: token } });

  assert.equal(admin.id, 7);
  assert.equal(admin.role, 'admin');
});

test('tool and MFA JWTs cannot become administrator sessions', async (t) => {
  const originalSecret = config.jwtSecret;
  const originalQuery = db.query;
  config.jwtSecret = 'test-secret-that-is-at-least-32-characters';
  let queryCalls = 0;
  db.query = async () => {
    queryCalls += 1;
    return [[{ id: 1, role: 'owner', status: 'active' }]];
  };
  t.after(() => {
    config.jwtSecret = originalSecret;
    db.query = originalQuery;
  });

  for (const purpose of ['roll-access', 'mfa-login']) {
    const token = jwt.sign({ id: 1, purpose }, config.jwtSecret, { expiresIn: '5m' });
    const request = { cookies: { [config.cookie.name]: token } };
    const response = {
      statusCode: 200,
      body: null,
      status(code) { this.statusCode = code; return this; },
      json(body) { this.body = body; return this; },
    };
    let nextCalls = 0;
    await requireAdmin(request, response, () => { nextCalls += 1; });
    assert.equal(response.statusCode, 401);
    assert.equal(nextCalls, 0);
    assert.equal(await optionalAdminSession(request), null);
  }
  assert.equal(queryCalls, 0);
});

test('administrator sessions are signed with an explicit purpose', (t) => {
  const originalSecret = config.jwtSecret;
  config.jwtSecret = 'test-secret-that-is-at-least-32-characters';
  t.after(() => { config.jwtSecret = originalSecret; });
  let token = '';
  issueSession({ cookie(_name, value) { token = value; } }, { id: 9 });
  const payload = jwt.verify(token, config.jwtSecret);
  assert.equal(payload.id, 9);
  assert.equal(payload.purpose, 'admin');
});
