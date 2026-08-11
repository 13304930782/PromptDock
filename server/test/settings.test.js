const test = require('node:test');
const assert = require('node:assert/strict');
const { parseSettingValue } = require('../src/lib/settings');

const savedSettings = {
  applications_open: true,
  cohort: 'promptdock-early-access-1',
  download_url: 'https://cuegroveapp.com/download',
  feedback_url: 'https://cuegroveapp.com/feedback',
  notify_email: 'mooncci@cuegroveapp.com',
  notify_on_new_application: true,
};

test('reads MySQL JSON columns returned as objects', () => {
  assert.deepEqual(parseSettingValue(savedSettings), savedSettings);
});

test('reads JSON columns returned as strings or buffers', () => {
  const json = JSON.stringify(savedSettings);
  assert.deepEqual(parseSettingValue(json), savedSettings);
  assert.deepEqual(parseSettingValue(Buffer.from(json)), savedSettings);
});

test('rejects invalid stored setting shapes', () => {
  assert.throws(() => parseSettingValue(null), /JSON object/);
  assert.throws(() => parseSettingValue('[]'), /JSON object/);
  assert.throws(() => parseSettingValue('{invalid'), SyntaxError);
});
