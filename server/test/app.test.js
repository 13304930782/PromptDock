const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const { createApp } = require('../src/app');
const config = require('../src/config');
const db = require('../src/db');

async function startServer(t) {
  const server = createApp().listen(0, '127.0.0.1');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  await new Promise((resolve) => server.once('listening', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

test('applies a restrictive CSP to API responses', async (t) => {
  const baseUrl = await startServer(t);
  const response = await fetch(`${baseUrl}/api/health`);

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-security-policy') || '', /default-src 'none'/);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
});

test('rejects state-changing requests without an allowed origin', async (t) => {
  const baseUrl = await startServer(t);
  const rejected = await fetch(`${baseUrl}/api/roll-access/logout`, { method: 'POST' });
  assert.equal(rejected.status, 403);

  const allowed = await fetch(`${baseUrl}/api/roll-access/logout`, {
    method: 'POST',
    headers: { Origin: config.siteUrl },
  });
  assert.equal(allowed.status, 200);
});

test('clears a roll session after its key is revoked or deleted', async (t) => {
  const originalSecret = config.jwtSecret;
  const originalQuery = db.query;
  config.jwtSecret = 'test-secret-that-is-at-least-32-characters';
  db.query = async () => [[]];
  t.after(() => {
    config.jwtSecret = originalSecret;
    db.query = originalQuery;
  });

  const baseUrl = await startServer(t);
  const token = jwt.sign({ id: 3, purpose: 'roll-access' }, config.jwtSecret, { expiresIn: '5m' });
  const response = await fetch(`${baseUrl}/api/roll-access/session`, {
    headers: { Cookie: `${config.cookie.name}_roll=${token}` },
  });

  assert.equal(response.status, 401);
  assert.match(response.headers.get('set-cookie') || '', new RegExp(`${config.cookie.name}_roll=;`));
});

test('records every access-key mutation without sensitive key material', async (t) => {
  const originalSecret = config.jwtSecret;
  const originalQuery = db.query;
  const originalGetConnection = db.getConnection;
  config.jwtSecret = 'test-secret-that-is-at-least-32-characters';
  const auditWrites = [];
  let commits = 0;
  db.query = async () => [[{
    id: 1,
    name: 'Owner',
    email: 'owner@example.com',
    role: 'owner',
    status: 'active',
    can_issue_roll_keys: 0,
    mfa_enabled_at: null,
  }]];
  db.getConnection = async () => ({
    async beginTransaction() {},
    async commit() { commits += 1; },
    async rollback() {},
    release() {},
    async query(sql, values = []) {
      const compact = sql.replace(/\s+/g, ' ').trim();
      if (compact.startsWith('INSERT INTO roll_access_keys')) return [{ insertId: 12 }];
      if (compact.startsWith('INSERT INTO roll_access_key_audit')) {
        auditWrites.push(values);
        return [{ affectedRows: values.length / 5 }];
      }
      if (compact.startsWith('SELECT rak.*')) return [[{
        id: 12,
        key_prefix: 'CG-created',
        created_by_name: 'Owner',
        expires_at: new Date(Date.now() + 60_000),
        revoked_at: null,
        last_used_at: null,
        use_count: 0,
        created_at: new Date(),
      }]];
      if (compact.includes('revoked_at IS NULL FOR UPDATE')) return [[{ id: 12, key_prefix: 'CG-revoke' }]];
      if (compact.includes('WHERE id=? FOR UPDATE')) return [[{ id: 12, key_prefix: 'CG-delete' }]];
      if (compact.includes('WHERE id IN') && compact.endsWith('FOR UPDATE')) {
        return [[{ id: 13, key_prefix: 'CG-bulk-one' }, { id: 14, key_prefix: 'CG-bulk-two' }]];
      }
      if (compact.startsWith('UPDATE roll_access_keys')) return [{ affectedRows: 1 }];
      if (compact.startsWith('DELETE FROM roll_access_keys')) return [{ affectedRows: values.length }];
      throw new Error(`Unexpected audit-test query: ${compact}`);
    },
  });
  t.after(() => {
    config.jwtSecret = originalSecret;
    db.query = originalQuery;
    db.getConnection = originalGetConnection;
  });

  const baseUrl = await startServer(t);
  const adminToken = jwt.sign({ id: 1, purpose: 'admin' }, config.jwtSecret, { expiresIn: '5m' });
  const headers = {
    Origin: config.siteUrl,
    Cookie: `${config.cookie.name}=${adminToken}`,
    'Content-Type': 'application/json',
  };
  const responses = [];
  responses.push(await fetch(`${baseUrl}/api/admin/roll-access-keys`, { method: 'POST', headers }));
  responses.push(await fetch(`${baseUrl}/api/admin/roll-access-keys/12/revoke`, { method: 'POST', headers }));
  responses.push(await fetch(`${baseUrl}/api/admin/roll-access-keys/12`, { method: 'DELETE', headers }));
  responses.push(await fetch(`${baseUrl}/api/admin/roll-access-keys`, {
      method: 'DELETE',
      headers,
      body: JSON.stringify({ ids: [13, 14] }),
    }));
  assert.deepEqual(responses.map((response) => response.status), [201, 200, 200, 200]);
  assert.equal(commits, 4);
  assert.deepEqual(auditWrites.map((values) => values[3]), ['create', 'revoke', 'delete', 'bulk_delete']);
  assert.equal(auditWrites[3][3], 'bulk_delete');
  assert.equal(auditWrites[3][8], 'bulk_delete');
  assert.equal(auditWrites[3][4], auditWrites[3][9]);
  const created = await responses[0].json();
  const auditStrings = auditWrites.flat().filter((value) => typeof value === 'string');
  assert.ok(!auditStrings.includes(created.access_key));
  assert.ok(auditStrings.every((value) => !/^[a-f0-9]{64}$/i.test(value)));
});
