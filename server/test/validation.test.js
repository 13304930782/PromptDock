const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isHttpUrl,
  normalizeEmail,
  passwordError,
  validateApplication,
} = require('../src/lib/validation');

test('normalizes applicant email', () => {
  assert.equal(normalizeEmail('  Person@Example.COM '), 'person@example.com');
});

test('accepts a complete application without retaining honeypot data', () => {
  const result = validateApplication({
    full_name: 'Lin Example',
    email: 'lin@example.com',
    role: 'creator',
    use_case: 'I organize prompts for a weekly writing workflow.',
    motivation: 'I want to test global search and provide careful feedback.',
    locale: 'en',
    consent: true,
    company_website: '',
  });
  assert.equal(result.ok, true);
  assert.equal(result.value.locale, 'en');
});

test('silently catches honeypot submissions', () => {
  const result = validateApplication({
    full_name: 'Spam Bot',
    email: 'bot@example.com',
    role: 'other',
    use_case: 'This is a long enough fake use case.',
    motivation: 'This is a long enough fake motivation.',
    locale: 'en',
    consent: true,
    company_website: 'https://spam.example',
  });
  assert.equal(result.ok, false);
  assert.equal(result.silent, true);
});

test('requires a strong administrator password', () => {
  assert.match(passwordError('onlyletters'), /letters and numbers/i);
  assert.equal(passwordError('forestgrove2026'), '');
});

test('only accepts HTTP URLs', () => {
  assert.equal(isHttpUrl('https://cuegrove.example/download'), true);
  assert.equal(isHttpUrl('javascript:alert(1)'), false);
  assert.equal(isHttpUrl(''), true);
});
