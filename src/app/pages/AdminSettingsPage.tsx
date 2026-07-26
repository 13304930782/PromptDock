import { FormEvent, useEffect, useState } from 'react';
import { Database, LockKeyhole, Send } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminUser, EarlyAccessSettings, MailSettings } from '../types';

type MailForm = MailSettings & {
  password: string;
  clear_password: boolean;
};

export default function AdminSettingsPage({ user }: { user: AdminUser }) {
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
    }).catch((loadError) => setError(loadError instanceof Error ? loadError.message : 'Unable to load settings.'));
    // The signed-in role remains stable for the lifetime of this page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user.role]);

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
      setNotice('Early Access settings saved.');
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Unable to save settings.');
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
      setNotice('SMTP settings saved. New messages will use this configuration.');
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Unable to save SMTP settings.');
    } finally {
      setWorking('');
    }
  };

  const testMail = async () => {
    setWorking('test-mail');
    try {
      const data = await api<{ message: string }>('/admin/settings/mail/test', { method: 'POST' });
      setNotice(data.message);
      setError('');
    } catch (mailError) {
      setError(mailError instanceof Error ? mailError.message : 'Unable to send test email.');
    } finally {
      setWorking('');
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>Settings</h1><p>Manage Early Access and mail delivery without editing server files.</p></div>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <div className="settings-console">
        <section className="admin-card settings-card">
          <div className="settings-heading">
            <div><h2>Early Access</h2><p>Application cohort, approval links, and administrator notifications.</p></div>
            <span className="settings-source"><Database size={14} />Database</span>
          </div>
          {settings && (
            <form className="settings-form" onSubmit={saveEarlyAccess}>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.applications_open} onChange={(event) => setSettings({ ...settings, applications_open: event.target.checked })} />
                <span>Accept new applications</span>
              </label>
              <label>Cohort identifier<input value={settings.cohort} maxLength={80} onChange={(event) => setSettings({ ...settings, cohort: event.target.value })} required /></label>
              <p className="settings-hint">Changing the cohort allows the same email to apply again in a future round.</p>
              <label>PromptDock download URL<input type="url" value={settings.download_url} onChange={(event) => setSettings({ ...settings, download_url: event.target.value })} placeholder="https://…" /></label>
              <p className="settings-hint">Approval remains disabled until this link is configured.</p>
              <label>Feedback URL<input type="url" value={settings.feedback_url} onChange={(event) => setSettings({ ...settings, feedback_url: event.target.value })} placeholder="https://…" /></label>
              <label>Notification email<input type="email" value={settings.notify_email} onChange={(event) => setSettings({ ...settings, notify_email: event.target.value })} placeholder="mooncci@cuegroveapp.com" /></label>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.notify_on_new_application} onChange={(event) => setSettings({ ...settings, notify_on_new_application: event.target.checked })} />
                <span>Email this address when a new application arrives</span>
              </label>
              <button className="button button-approve" type="submit" disabled={Boolean(working)}>Save Early Access settings</button>
            </form>
          )}
        </section>

        {user.role === 'owner' && (
          <section className="admin-card settings-card">
            <div className="settings-heading">
              <div><h2>SMTP mail delivery</h2><p>Configure the mailbox used for decisions, alerts, and password resets.</p></div>
              {mail && <span className={`settings-source ${mail.ready ? 'ready' : ''}`}>{mail.ready ? 'Ready' : 'Incomplete'} · {mail.source}</span>}
            </div>
            {mail && (
              <form className="settings-form" onSubmit={saveMail}>
                {mail.configuration_error && <div className="admin-alert error" role="alert">{mail.configuration_error} Re-enter the SMTP password and save.</div>}
                <label className="toggle-label">
                  <input type="checkbox" checked={mail.enabled} onChange={(event) => setMail({ ...mail, enabled: event.target.checked })} />
                  <span>Enable outgoing email</span>
                </label>
                <div className="settings-form-grid">
                  <label>SMTP host<input value={mail.host} onChange={(event) => setMail({ ...mail, host: event.target.value })} placeholder="mail.cuegroveapp.com" /></label>
                  <label>Port<input type="number" min={1} max={65535} value={mail.port} onChange={(event) => setMail({ ...mail, port: Number(event.target.value) })} /></label>
                  <label>Connection security
                    <select value={mail.secure ? 'tls' : 'starttls'} onChange={(event) => setMail({ ...mail, secure: event.target.value === 'tls' })}>
                      <option value="starttls">STARTTLS / plain connection</option>
                      <option value="tls">TLS from connection start</option>
                    </select>
                  </label>
                  <label>Timeout (ms)<input type="number" min={1000} max={120000} step={1000} value={mail.timeout_ms} onChange={(event) => setMail({ ...mail, timeout_ms: Number(event.target.value) })} /></label>
                </div>
                <label>HELO hostname<input value={mail.helo_name} onChange={(event) => setMail({ ...mail, helo_name: event.target.value })} placeholder="mail.cuegroveapp.com" /></label>
                <label className="toggle-label">
                  <input type="checkbox" checked={mail.auth_required} onChange={(event) => setMail({ ...mail, auth_required: event.target.checked })} />
                  <span>SMTP server requires username and password</span>
                </label>
                {mail.auth_required && (
                  <div className="settings-form-grid">
                    <label>SMTP username<input value={mail.user} onChange={(event) => setMail({ ...mail, user: event.target.value })} autoComplete="username" /></label>
                    <label>SMTP password
                      <input
                        type="password"
                        value={mail.password}
                        onChange={(event) => setMail({ ...mail, password: event.target.value, clear_password: false })}
                        autoComplete="new-password"
                        placeholder={mail.password_configured ? 'Saved — leave blank to keep' : 'Enter SMTP password'}
                      />
                    </label>
                  </div>
                )}
                {mail.auth_required && mail.password_configured && (
                  <label className="toggle-label danger-toggle">
                    <input type="checkbox" checked={mail.clear_password} onChange={(event) => setMail({ ...mail, clear_password: event.target.checked, password: '' })} />
                    <span>Remove the saved SMTP password</span>
                  </label>
                )}
                <div className="settings-form-grid">
                  <label>From address<input value={mail.from} onChange={(event) => setMail({ ...mail, from: event.target.value })} placeholder="CueGrove <earlyaccess@cuegroveapp.com>" /></label>
                  <label>Reply-to address<input value={mail.reply_to} onChange={(event) => setMail({ ...mail, reply_to: event.target.value })} placeholder="mooncci@cuegroveapp.com" /></label>
                </div>
                <p className="settings-hint">The SMTP password is encrypted before it is stored and is never returned to the browser. Saving once moves mail configuration from environment fallback to the database.</p>
                <div className="settings-actions">
                  <button className="button button-approve" type="submit" disabled={Boolean(working)}>Save SMTP settings</button>
                  <button className="button button-secondary" type="button" disabled={Boolean(working) || !mail.ready} onClick={testMail}><Send size={16} />Send test email</button>
                </div>
              </form>
            )}
          </section>
        )}

        <section className="admin-card settings-card protected-settings">
          <LockKeyhole size={22} />
          <div>
            <h2>Protected server settings</h2>
            <p>Database credentials, JWT signing secret, cookie security, and process ports remain in <code>server/.env</code>. These boot-level secrets cannot be viewed or changed from the website.</p>
          </div>
        </section>
      </div>
    </>
  );
}
