const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const config = require('../src/config');
const { issueSession, sessionVersionMatches } = require('../src/middleware/auth');

test('administrator sessions carry and enforce the database token version', () => {
  const originalSecret = config.jwtSecret;
  config.jwtSecret = 'test-secret-that-is-longer-than-thirty-two-characters';
  let sessionToken = '';

  try {
    issueSession({ cookie: (_name, value) => { sessionToken = value; } }, {
      id: 12,
      token_version: 4,
    });
    const payload = jwt.verify(sessionToken, config.jwtSecret);
    assert.equal(sessionVersionMatches(payload, { token_version: 4 }), true);
    assert.equal(sessionVersionMatches(payload, { token_version: 5 }), false);
    assert.equal(sessionVersionMatches({ id: 12 }, { token_version: 0 }), false);
  } finally {
    config.jwtSecret = originalSecret;
  }
});
