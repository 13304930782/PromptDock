const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

test('applies a restrictive CSP to API responses', async (t) => {
  const server = createApp().listen(0, '127.0.0.1');
  t.after(() => new Promise((resolve) => server.close(resolve)));

  await new Promise((resolve) => server.once('listening', resolve));
  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/api/health`);

  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-security-policy') || '', /default-src 'none'/);
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
});
