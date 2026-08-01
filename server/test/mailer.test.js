const test = require('node:test');
const assert = require('node:assert/strict');
const config = require('../src/config');
const {
  buildFeedbackNotification,
  buildPasswordResetUrl,
  buildDecisionMessage,
  escapeHtml,
  mailReady,
  smtpTransportOptions,
} = require('../src/lib/mailer');

const settings = {
  download_url: 'https://cuegrove.example/download',
  feedback_url: 'https://cuegrove.example/feedback',
};

test('builds the fixed Chinese approval subject and download action', () => {
  const message = buildDecisionMessage({
    id: 1,
    full_name: '小林',
    email: 'lin@example.com',
    locale: 'zh',
    status: 'approved',
    applicant_message: '',
  }, settings);
  assert.equal(message.subject, '[CueGrove] PromptDock Early Access 申请已通过');
  assert.match(message.html, /下载 PromptDock/);
  assert.match(message.text, /https:\/\/cuegrove\.example\/download/);
});

test('builds the fixed English rejection subject without download URL', () => {
  const message = buildDecisionMessage({
    id: 2,
    full_name: 'Lin',
    email: 'lin@example.com',
    locale: 'en',
    status: 'rejected',
    applicant_message: 'Thank you for your time.',
  }, settings);
  assert.equal(message.subject, '[CueGrove] Your PromptDock Early Access application');
  assert.doesNotMatch(message.html, />Download PromptDock</);
  assert.match(message.text, /Thank you for your time/);
});

test('escapes applicant-provided HTML in branded mail', () => {
  assert.equal(escapeHtml('<img src=x onerror=alert(1)>'), '&lt;img src=x onerror=alert(1)&gt;');
  const message = buildDecisionMessage({
    id: 3,
    full_name: '<script>alert(1)</script>',
    email: 'lin@example.com',
    locale: 'en',
    status: 'approved',
    applicant_message: '<b>hello</b>',
  }, settings);
  assert.doesNotMatch(message.html, /<script>/);
  assert.doesNotMatch(message.html, /<b>hello<\/b>/);
});

test('builds private feedback reply notifications without exposing message content', () => {
  const message = buildFeedbackNotification({
    actor: 'developer',
    locale: 'zh',
    recipientName: '<测试用户>',
    reportTitle: '<script>反馈标题</script>',
    actionUrl: 'https://cuegrove.example/feedback/private-token',
  });
  assert.match(message.subject, /开发者回复/);
  assert.match(message.html, /查看开发者回复/);
  assert.doesNotMatch(message.html, /<script>/);
  assert.match(message.text, /https:\/\/cuegrove\.example\/feedback\/private-token/);
});

test('keeps password reset tokens out of request URLs and referrer logs', () => {
  const resetUrl = buildPasswordResetUrl('secret token');
  assert.match(resetUrl, /\/admin\/reset-password#token=secret%20token$/);
  assert.doesNotMatch(resetUrl, /\?token=/);
});

test('supports Google Workspace relay authenticated by server IP', () => {
  const original = { ...config.mail };
  Object.assign(config.mail, {
    enabled: true,
    host: 'smtp-relay.gmail.com',
    port: 587,
    secure: false,
    authRequired: false,
    timeoutMs: 20000,
    heloName: 'mail.cuegroveapp.com',
    user: '',
    pass: '',
    from: 'CueGrove <mooncci@cuegroveapp.com>',
  });

  try {
    assert.equal(mailReady(), true);
    assert.deepEqual(smtpTransportOptions(), {
      host: 'smtp-relay.gmail.com',
      port: 587,
      secure: false,
      connectionTimeout: 20000,
      greetingTimeout: 20000,
      socketTimeout: 20000,
      name: 'mail.cuegroveapp.com',
    });
  } finally {
    Object.assign(config.mail, original);
  }
});

test('still requires credentials for authenticated SMTP', () => {
  const original = { ...config.mail };
  Object.assign(config.mail, {
    enabled: true,
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    authRequired: true,
    timeoutMs: 20000,
    heloName: '',
    user: '',
    pass: '',
    from: 'CueGrove <mooncci@cuegroveapp.com>',
  });

  try {
    assert.equal(mailReady(), false);
  } finally {
    Object.assign(config.mail, original);
  }
});
