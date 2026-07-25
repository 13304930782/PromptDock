const nodemailer = require('nodemailer');
const db = require('../db');
const config = require('../config');
const { string } = require('./validation');

function escapeHtml(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function cleanHeader(value) {
  return String(value || '').replace(/[\r\n]+/g, ' ').trim();
}

function mailReady() {
  return Boolean(
    config.mail.enabled &&
    config.mail.host &&
    config.mail.from &&
    (
      !config.mail.authRequired ||
      (config.mail.user && config.mail.pass)
    ),
  );
}

function smtpTransportOptions() {
  const options = {
    host: config.mail.host,
    port: config.mail.port,
    secure: config.mail.secure,
  };
  if (config.mail.authRequired) {
    options.auth = {
      user: config.mail.user,
      pass: config.mail.pass,
    };
  }
  return options;
}

function transporter() {
  if (!mailReady()) {
    throw new Error('SMTP is disabled or incomplete.');
  }
  return nodemailer.createTransport(smtpTransportOptions());
}

function emailFrame({ locale, title, bodyHtml, actionLabel, actionUrl, footer }) {
  const preheader = locale === 'zh'
    ? '来自 CueGrove 的 PromptDock Early Access 消息'
    : 'A PromptDock Early Access message from CueGrove';
  const action = actionUrl
    ? `<p style="margin:30px 0 24px;text-align:center"><a href="${escapeHtml(actionUrl)}" style="display:inline-block;padding:13px 24px;border-radius:999px;background:#0d4b3b;color:#ffffff;text-decoration:none;font-weight:700">${escapeHtml(actionLabel)}</a></p>`
    : '';

  return `<!doctype html>
<html lang="${locale === 'zh' ? 'zh-CN' : 'en'}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#f6f1e5;color:#153027;font-family:Arial,'Noto Sans SC',sans-serif">
  <div style="display:none;max-height:0;overflow:hidden">${escapeHtml(preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f6f1e5">
    <tr><td align="center" style="padding:38px 16px">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px">
        <tr><td style="padding:0 8px 20px;color:#0d4b3b;font-size:23px;font-weight:700">
          <span style="display:inline-block;width:12px;height:12px;margin-right:9px;border-radius:50%;background:#f4bf4f"></span>CueGrove
        </td></tr>
        <tr><td style="padding:40px;border:1px solid #e6decb;border-radius:28px;background:#fffef9;box-shadow:0 16px 40px rgba(13,75,59,.08)">
          <div style="width:54px;height:6px;margin-bottom:26px;border-radius:999px;background:linear-gradient(90deg,#70bc5b,#f4bf4f)"></div>
          <h1 style="margin:0;color:#082f27;font-family:Georgia,'Noto Serif SC',serif;font-size:34px;line-height:1.2">${escapeHtml(title)}</h1>
          <div style="margin-top:23px;color:#52685f;font-size:16px;line-height:1.8">${bodyHtml}</div>
          ${action}
          <div style="margin-top:30px;padding-top:22px;border-top:1px solid #ece4d1;color:#829188;font-size:12px;line-height:1.6">${escapeHtml(footer)}</div>
        </td></tr>
        <tr><td style="padding:22px 8px 0;color:#81938b;font-size:11px;line-height:1.6">CueGrove · Calm, dependable tools that respect your privacy.</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function buildDecisionMessage(application, settings) {
  const approved = application.status === 'approved';
  const zh = application.locale === 'zh';
  const applicantMessage = string(application.applicant_message, 1500);

  const subject = approved
    ? (zh ? '[CueGrove] PromptDock Early Access 申请已通过' : '[CueGrove] You’re in — PromptDock Early Access')
    : (zh ? '[CueGrove] PromptDock Early Access 申请结果' : '[CueGrove] Your PromptDock Early Access application');

  const title = approved
    ? (zh ? '欢迎加入 PromptDock Early Access' : 'Welcome to PromptDock Early Access')
    : (zh ? '感谢你的 Early Access 申请' : 'Thank you for applying');

  const intro = approved
    ? (zh
      ? `${application.full_name}，你好！你的 PromptDock Early Access 申请已经通过。`
      : `Hi ${application.full_name}, your PromptDock Early Access application has been approved.`)
    : (zh
      ? `${application.full_name}，你好！感谢你认真填写 PromptDock Early Access 申请。经过本轮评估，我们暂时无法为你开放测试资格。`
      : `Hi ${application.full_name}, thank you for your thoughtful PromptDock Early Access application. We cannot offer a place in this round.`);

  const guidance = approved
    ? (zh
      ? '请通过下方按钮下载测试版本。Early Access 软件仍在持续打磨，请先备份重要内容，并通过反馈入口告诉我们你的真实体验。'
      : 'Use the button below to download the preview. Early Access software is still evolving, so please keep backups and share your experience through the feedback link.')
    : (zh
      ? '这并不代表你的想法不重要，只是当前测试名额和场景有限。我们会保留本轮记录，并在未来更合适的机会出现时继续与你联系。'
      : 'This does not diminish your ideas; this round simply has limited places and testing needs. We will keep this application on record for future opportunities.');

  const customHtml = applicantMessage
    ? `<div style="margin-top:20px;padding:16px;border-radius:14px;background:#f6f1e5;color:#425b51"><strong>${zh ? '给你的补充说明' : 'A note for you'}</strong><br>${escapeHtml(applicantMessage).replace(/\n/g, '<br>')}</div>`
    : '';

  const feedbackHtml = approved && settings.feedback_url
    ? `<p>${zh ? '反馈入口' : 'Feedback'}：<a style="color:#1f7353" href="${escapeHtml(settings.feedback_url)}">${escapeHtml(settings.feedback_url)}</a></p>`
    : '';

  const html = emailFrame({
    locale: application.locale,
    title,
    bodyHtml: `<p style="margin:0 0 16px">${escapeHtml(intro)}</p><p style="margin:0">${escapeHtml(guidance)}</p>${customHtml}${feedbackHtml}`,
    actionLabel: approved ? (zh ? '下载 PromptDock' : 'Download PromptDock') : '',
    actionUrl: approved ? settings.download_url : '',
    footer: zh
      ? '这封邮件仅与你的 PromptDock Early Access 申请有关。CueGrove 不会出售你的申请信息。'
      : 'This email relates only to your PromptDock Early Access application. CueGrove never sells your application data.',
  });

  const text = [
    intro,
    '',
    guidance,
    applicantMessage ? `\n${zh ? '补充说明' : 'Note'}:\n${applicantMessage}` : '',
    approved ? `\n${zh ? '下载' : 'Download'}: ${settings.download_url}` : '',
    approved && settings.feedback_url ? `${zh ? '反馈' : 'Feedback'}: ${settings.feedback_url}` : '',
  ].filter(Boolean).join('\n');

  return { subject, title, html, text, kind: approved ? 'approved' : 'rejected' };
}

async function sendRaw({ to, subject, text, html }) {
  const mailer = transporter();
  await mailer.sendMail({
    from: config.mail.from,
    replyTo: config.mail.replyTo || undefined,
    to,
    subject: cleanHeader(subject),
    text,
    html,
  });
}

async function nextAttempt(applicationId, kind) {
  const [rows] = await db.query(
    'SELECT COALESCE(MAX(attempt_number), 0) + 1 AS next_attempt FROM mail_delivery_logs WHERE application_id <=> ? AND mail_kind=?',
    [applicationId || null, kind],
  );
  return Number(rows[0]?.next_attempt || 1);
}

async function deliverLogged({ applicationId = null, kind, locale, to, subject, text, html }) {
  const attempt = await nextAttempt(applicationId, kind);
  try {
    await sendRaw({ to, subject, text, html });
    await db.query(
      `INSERT INTO mail_delivery_logs
       (application_id, mail_kind, locale, recipient, subject, status, attempt_number, sent_at)
       VALUES (?, ?, ?, ?, ?, 'sent', ?, NOW())`,
      [applicationId, kind, locale, to, cleanHeader(subject), attempt],
    );
    return { status: 'sent' };
  } catch (error) {
    const reason = string(error.message || 'Mail delivery failed.', 500);
    await db.query(
      `INSERT INTO mail_delivery_logs
       (application_id, mail_kind, locale, recipient, subject, status, attempt_number, error_message)
       VALUES (?, ?, ?, ?, ?, 'failed', ?, ?)`,
      [applicationId, kind, locale, to, cleanHeader(subject), attempt, reason],
    );
    return { status: 'failed', error: reason };
  }
}

async function sendDecisionEmail(application, settings) {
  const message = buildDecisionMessage(application, settings);
  return deliverLogged({
    applicationId: application.id,
    kind: message.kind,
    locale: application.locale,
    to: application.email,
    ...message,
  });
}

async function sendNewApplicationNotification(application, settings) {
  if (!settings.notify_on_new_application || !settings.notify_email) return { status: 'skipped' };
  const reviewUrl = `${config.siteUrl}/admin/early-access`;
  const subject = `[CueGrove] New PromptDock Early Access application — ${cleanHeader(application.full_name)}`;
  const text = `A new application is ready for review.\n\nName: ${application.full_name}\nEmail: ${application.email}\nRole: ${application.role}\n\nReview: ${reviewUrl}`;
  const html = emailFrame({
    locale: 'en',
    title: 'A new application is ready',
    bodyHtml: `<p><strong>Name:</strong> ${escapeHtml(application.full_name)}</p><p><strong>Email:</strong> ${escapeHtml(application.email)}</p><p><strong>Role:</strong> ${escapeHtml(application.role)}</p>`,
    actionLabel: 'Review application',
    actionUrl: reviewUrl,
    footer: 'This is an administrator notification from CueGrove.',
  });
  return deliverLogged({
    applicationId: application.id,
    kind: 'new_application',
    locale: 'en',
    to: settings.notify_email,
    subject,
    text,
    html,
  });
}

async function sendPasswordReset(admin, token) {
  const resetUrl = `${config.siteUrl}/admin/reset-password?token=${encodeURIComponent(token)}`;
  const subject = '[CueGrove] Reset your administrator password';
  const text = `Use this link to reset your CueGrove administrator password. It expires in ${config.passwordResetMinutes} minutes.\n\n${resetUrl}`;
  const html = emailFrame({
    locale: 'en',
    title: 'Reset your administrator password',
    bodyHtml: `<p>Hi ${escapeHtml(admin.name)}, use the button below to choose a new password. The link expires in ${config.passwordResetMinutes} minutes.</p>`,
    actionLabel: 'Reset password',
    actionUrl: resetUrl,
    footer: 'If you did not request this, you can safely ignore this email.',
  });
  return deliverLogged({
    kind: 'password_reset',
    locale: 'en',
    to: admin.email,
    subject,
    text,
    html,
  });
}

async function sendTestEmail(to) {
  const subject = '[CueGrove] SMTP test';
  const text = 'Your CueGrove SMTP configuration is working.';
  const html = emailFrame({
    locale: 'en',
    title: 'SMTP is ready',
    bodyHtml: '<p>Your CueGrove server can send branded transactional email.</p>',
    actionLabel: '',
    actionUrl: '',
    footer: 'Sent from CueGrove administrator settings.',
  });
  return deliverLogged({ kind: 'test', locale: 'en', to, subject, text, html });
}

module.exports = {
  buildDecisionMessage,
  cleanHeader,
  emailFrame,
  escapeHtml,
  mailReady,
  smtpTransportOptions,
  sendDecisionEmail,
  sendNewApplicationNotification,
  sendPasswordReset,
  sendTestEmail,
};
