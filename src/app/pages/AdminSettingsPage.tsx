import { FormEvent, useEffect, useState } from 'react';
import { Database, LockKeyhole, Send } from 'lucide-react';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { AdminUser, EarlyAccessSettings, MailSettings } from '../types';

type MailForm = MailSettings & {
  password: string;
  clear_password: boolean;
};

export default function AdminSettingsPage({ user }: { user: AdminUser }) {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [settings, setSettings] = useState<EarlyAccessSettings | null>(null);
  const [mail, setMail] = useState<MailForm | null>(null);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState('');

  useEffect(() => {
    Promise.all([
      api<{ settings: EarlyAccessSettings }>('/admin/settings/early-access'),
      user.role === 'owner'
        ? api<{ settings: MailSettings }>('/admin/settings/mail')
        : Promise.resolve(null),
    ]).then(([settingsData, mailData]) => {
      setSettings(settingsData.settings);
      if (mailData) setMail({ ...mailData.settings, password: '', clear_password: false });
    }).catch((loadError) => setError(loadError instanceof Error ? loadError.message : (zh ? '无法加载设置。' : 'Unable to load settings.')));
    // The signed-in role remains stable for the lifetime of this page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user.role, zh]);

  const saveEarlyAccess = async (event: FormEvent) => {
    event.preventDefault();
    if (!settings) return;
    setWorking('early-access');
    try {
      const data = await api<{ settings: EarlyAccessSettings }>('/admin/settings/early-access', {
        method: 'PUT',
        body: JSON.stringify(settings),
      });
      setSettings(data.settings);
      setNotice(zh ? '内测设置已保存。' : 'Early Access settings saved.');
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : (zh ? '无法保存设置。' : 'Unable to save settings.'));
    } finally {
      setWorking('');
    }
  };

  const saveMail = async (event: FormEvent) => {
    event.preventDefault();
    if (!mail) return;
    setWorking('mail');
    try {
      const data = await api<{ settings: MailSettings }>('/admin/settings/mail', {
        method: 'PUT',
        body: JSON.stringify(mail),
      });
      setMail({ ...data.settings, password: '', clear_password: false });
      setNotice(zh ? 'SMTP 设置已保存，新邮件将使用此配置。' : 'SMTP settings saved. New messages will use this configuration.');
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : (zh ? '无法保存 SMTP 设置。' : 'Unable to save SMTP settings.'));
    } finally {
      setWorking('');
    }
  };

  const testMail = async () => {
    setWorking('test-mail');
    try {
      const data = await api<{ message: string }>('/admin/settings/mail/test', {
        method: 'POST',
        timeoutMs: Math.max(15_000, (mail?.timeout_ms ?? 20_000) + 5_000),
      });
      setNotice(data.message);
      setError('');
    } catch (mailError) {
      setError(mailError instanceof Error ? mailError.message : (zh ? '无法发送测试邮件。' : 'Unable to send test email.'));
    } finally {
      setWorking('');
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>{zh ? '设置' : 'Settings'}</h1><p>{zh ? '无需编辑服务器文件即可管理内测和邮件发送。' : 'Manage Early Access and mail delivery without editing server files.'}</p></div>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <div className="settings-console">
        <section className="admin-card settings-card">
          <div className="settings-heading">
            <div><h2>{zh ? '内测申请' : 'Early Access'}</h2><p>{zh ? '管理申请批次、通过链接和管理员通知。' : 'Application cohort, approval links, and administrator notifications.'}</p></div>
            <span className="settings-source"><Database size={14} />{zh ? '数据库' : 'Database'}</span>
          </div>
          {settings && (
            <form className="settings-form" onSubmit={saveEarlyAccess}>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.applications_open} onChange={(event) => setSettings({ ...settings, applications_open: event.target.checked })} />
                <span>{zh ? '接受新申请' : 'Accept new applications'}</span>
              </label>
              <label>{zh ? '批次标识' : 'Cohort identifier'}<input value={settings.cohort} maxLength={80} onChange={(event) => setSettings({ ...settings, cohort: event.target.value })} required /></label>
              <p className="settings-hint">{zh ? '更改批次后，同一邮箱可在未来的批次中再次申请。' : 'Changing the cohort allows the same email to apply again in a future round.'}</p>
              <label>PromptDock {zh ? '下载地址' : 'download URL'}<input type="url" value={settings.download_url} onChange={(event) => setSettings({ ...settings, download_url: event.target.value })} placeholder="https://…" /></label>
              <p className="settings-hint">{zh ? '配置此链接之前无法通过申请。' : 'Approval remains disabled until this link is configured.'}</p>
              <label>{zh ? '反馈地址' : 'Feedback URL'}<input type="url" value={settings.feedback_url} onChange={(event) => setSettings({ ...settings, feedback_url: event.target.value })} placeholder="https://…" /></label>
              <label>{zh ? '通知邮箱' : 'Notification email'}<input type="email" value={settings.notify_email} onChange={(event) => setSettings({ ...settings, notify_email: event.target.value })} placeholder="mooncci@cuegroveapp.com" /></label>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.notify_on_new_application} onChange={(event) => setSettings({ ...settings, notify_on_new_application: event.target.checked })} />
                <span>{zh ? '收到新申请时向此地址发送邮件' : 'Email this address when a new application arrives'}</span>
              </label>
              <button className="button button-approve" type="submit" disabled={Boolean(working)}>{zh ? '保存内测设置' : 'Save Early Access settings'}</button>
            </form>
          )}
        </section>

        {user.role === 'owner' && (
          <section className="admin-card settings-card">
            <div className="settings-heading">
              <div><h2>{zh ? 'SMTP 邮件发送' : 'SMTP mail delivery'}</h2><p>{zh ? '配置用于审核结果、提醒和密码重置的邮箱。' : 'Configure the mailbox used for decisions, alerts, and password resets.'}</p></div>
              {mail && <span className={`settings-source ${mail.ready ? 'ready' : ''}`}>{mail.ready ? (zh ? '就绪' : 'Ready') : (zh ? '未完成' : 'Incomplete')} · {mail.source}</span>}
            </div>
            {mail && (
              <form className="settings-form" onSubmit={saveMail}>
                {mail.configuration_error && <div className="admin-alert error" role="alert">{mail.configuration_error} {zh ? '请重新输入 SMTP 密码并保存。' : 'Re-enter the SMTP password and save.'}</div>}
                <label className="toggle-label">
                  <input type="checkbox" checked={mail.enabled} onChange={(event) => setMail({ ...mail, enabled: event.target.checked })} />
                  <span>{zh ? '启用邮件发送' : 'Enable outgoing email'}</span>
                </label>
                <div className="settings-form-grid">
                  <label>SMTP {zh ? '主机' : 'host'}<input value={mail.host} onChange={(event) => setMail({ ...mail, host: event.target.value })} placeholder="mail.cuegroveapp.com" /></label>
                  <label>{zh ? '端口' : 'Port'}<input type="number" min={1} max={65535} value={mail.port} onChange={(event) => setMail({ ...mail, port: Number(event.target.value) })} /></label>
                  <label>{zh ? '连接安全' : 'Connection security'}
                    <select value={mail.secure ? 'tls' : 'starttls'} onChange={(event) => setMail({ ...mail, secure: event.target.value === 'tls' })}>
                      <option value="starttls">STARTTLS / {zh ? '普通连接' : 'plain connection'}</option>
                      <option value="tls">{zh ? '连接开始即使用 TLS' : 'TLS from connection start'}</option>
                    </select>
                  </label>
                  <label>{zh ? '超时（毫秒）' : 'Timeout (ms)'}<input type="number" min={1000} max={120000} step={1000} value={mail.timeout_ms} onChange={(event) => setMail({ ...mail, timeout_ms: Number(event.target.value) })} /></label>
                </div>
                <label>HELO {zh ? '主机名' : 'hostname'}<input value={mail.helo_name} onChange={(event) => setMail({ ...mail, helo_name: event.target.value })} placeholder="mail.cuegroveapp.com" /></label>
                <label className="toggle-label">
                  <input type="checkbox" checked={mail.auth_required} onChange={(event) => setMail({ ...mail, auth_required: event.target.checked })} />
                  <span>{zh ? 'SMTP 服务器需要用户名和密码' : 'SMTP server requires username and password'}</span>
                </label>
                {mail.auth_required && (
                  <div className="settings-form-grid">
                    <label>SMTP {zh ? '用户名' : 'username'}<input value={mail.user} onChange={(event) => setMail({ ...mail, user: event.target.value })} autoComplete="username" /></label>
                    <label>SMTP {zh ? '密码' : 'password'}
                      <input
                        type="password"
                        value={mail.password}
                        onChange={(event) => setMail({ ...mail, password: event.target.value, clear_password: false })}
                        autoComplete="new-password"
                        autoCapitalize="none"
                        spellCheck={false}
                        placeholder={mail.password_configured ? (zh ? '已保存，留空表示保持不变' : 'Saved — leave blank to keep') : (zh ? '输入 SMTP 密码' : 'Enter SMTP password')}
                      />
                    </label>
                  </div>
                )}
                {mail.auth_required && mail.password_configured && (
                  <label className="toggle-label danger-toggle">
                    <input type="checkbox" checked={mail.clear_password} onChange={(event) => setMail({ ...mail, clear_password: event.target.checked, password: '' })} />
                    <span>{zh ? '删除已保存的 SMTP 密码' : 'Remove the saved SMTP password'}</span>
                  </label>
                )}
                <div className="settings-form-grid">
                  <label>{zh ? '发件地址' : 'From address'}<input value={mail.from} onChange={(event) => setMail({ ...mail, from: event.target.value })} placeholder="CueGrove <earlyaccess@cuegroveapp.com>" /></label>
                  <label>{zh ? '回复地址' : 'Reply-to address'}<input value={mail.reply_to} onChange={(event) => setMail({ ...mail, reply_to: event.target.value })} placeholder="mooncci@cuegroveapp.com" /></label>
                </div>
                <p className="settings-hint">{zh ? 'SMTP 密码加密存储，且不会返回浏览器。保存后，邮件配置将从环境变量后备方案迁移到数据库。' : 'The SMTP password is encrypted before it is stored and is never returned to the browser. Saving once moves mail configuration from environment fallback to the database.'}</p>
                <div className="settings-actions">
                  <button className="button button-approve" type="submit" disabled={Boolean(working)}>{zh ? '保存 SMTP 设置' : 'Save SMTP settings'}</button>
                  <button className="button button-secondary" type="button" disabled={Boolean(working) || !mail.ready} onClick={testMail}><Send size={16} />{zh ? '发送测试邮件' : 'Send test email'}</button>
                </div>
              </form>
            )}
          </section>
        )}

        <section className="admin-card settings-card protected-settings">
          <LockKeyhole size={22} />
          <div>
            <h2>{zh ? '受保护的服务器设置' : 'Protected server settings'}</h2>
            <p>{zh ? '数据库凭据、JWT 签名密钥、Cookie 安全配置和进程端口仍保存在' : 'Database credentials, JWT signing secret, cookie security, and process ports remain in'} <code>server/.env</code>{zh ? '。这些启动级密钥不能在网站中查看或修改。' : '. These boot-level secrets cannot be viewed or changed from the website.'}</p>
          </div>
        </section>
      </div>
    </>
  );
}
