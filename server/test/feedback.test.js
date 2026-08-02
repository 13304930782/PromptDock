const test = require('node:test');
const assert = require('node:assert/strict');
const { feedbackPortalUrl } = require('../src/routes/feedback');

test('feedback access tokens stay in the URL fragment', () => {
  const url = feedbackPortalUrl('private_token-value', 42);
  const parsed = new URL(url);
  assert.equal(parsed.pathname, '/feedback/portal');
  assert.equal(parsed.search, '');
  assert.equal(parsed.hash, '#token=private_token-value&report=42');
});
