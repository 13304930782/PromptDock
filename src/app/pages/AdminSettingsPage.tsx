import { FormEvent, useEffect, useState } from 'react';
import { Send } from 'lucide-react';
import { api } from '../lib/api';
import type { EarlyAccessSettings } from '../types';

type MailStatus = {
  enabled: boolean;
  host_configured: boolean;
  auth_required: boolean;
  user_configured: boolean;
  password_configured: boolean;
  from: string;
};

export default function AdminSettingsPage() {
  const [settings, setSettings] = useState<EarlyAccessSettings | null>(null);
  const [mail, setMail] = useState<MailStatus | null>(null);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState(false);

  useEffect(() => {
    Promise.all([
      api<{ settings: EarlyAccessSettings }>('/admin/settings/early-access'),
      api<{ mail: MailStatus }>('/admin/settings/mail/status'),
    ]).then(([settingsData, mailData]) => {
      setSettings(settingsData.settings);
      setMail(mailData.mail);
    }).catch((loadError) => setError(loadError instanceof Error ? loadError.message : 'Unable to load settings.'));
  }, []);

  const save = async (event: FormEvent) => {
    event.preventDefault();
    if (!settings) return;
    setWorking(true);
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
      setWorking(false);
    }
  };

  const testMail = async () => {
    setWorking(true);
    try {
      const data = await api<{ message: string }>('/admin/settings/mail/test', { method: 'POST' });
      setNotice(data.message);
      setError('');
    } catch (mailError) {
      setError(mailError instanceof Error ? mailError.message : 'Unable to send test email.');
    } finally {
      setWorking(false);
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>Settings</h1><p>Control the current cohort, delivery links, and mail readiness.</p></div>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}
      <div className="settings-layout">
        <section className="admin-card settings-card">
          <h2>Early Access</h2>
          {settings && (
            <form className="settings-form" onSubmit={save}>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.applications_open} onChange={(event) => setSettings({ ...settings, applications_open: event.target.checked })} />
                <span>Accept new applications</span>
              </label>
              <label>Cohort identifier<input value={settings.cohort} maxLength={80} onChange={(event) => setSettings({ ...settings, cohort: event.target.value })} required /></label>
              <p className="settings-hint">Changing the cohort allows the same email to apply again in a future round.</p>
              <label>PromptDock download URL<input type="url" value={settings.download_url} onChange={(event) => setSettings({ ...settings, download_url: event.target.value })} placeholder="https://…" /></label>
              <p className="settings-hint">Approval remains disabled until this link is configured.</p>
              <label>Feedback URL<input type="url" value={settings.feedback_url} onChange={(event) => setSettings({ ...settings, feedback_url: event.target.value })} placeholder="https://…" /></label>
              <label>Notification email<input type="email" value={settings.notify_email} onChange={(event) => setSettings({ ...settings, notify_email: event.target.value })} placeholder="team@cuegrove.com" /></label>
              <label className="toggle-label">
                <input type="checkbox" checked={settings.notify_on_new_application} onChange={(event) => setSettings({ ...settings, notify_on_new_application: event.target.checked })} />
                <span>Email me when a new application arrives</span>
              </label>
              <button className="button button-approve" type="submit" disabled={working}>Save settings</button>
            </form>
          )}
        </section>
        <aside className="admin-card settings-card">
          <h2>SMTP readiness</h2>
          {mail && (
            <>
              <ul className="mail-status-list">
                <li><span>Mail enabled</span><strong>{mail.enabled ? 'Yes' : 'No'}</strong></li>
                <li><span>SMTP host</span><strong>{mail.host_configured ? 'Configured' : 'Missing'}</strong></li>
                <li><span>Authentication</span><strong>{mail.auth_required ? 'Username and password' : 'Server IP allowlist'}</strong></li>
                <li><span>SMTP user</span><strong>{mail.auth_required ? (mail.user_configured ? 'Configured' : 'Missing') : 'Not required'}</strong></li>
                <li><span>SMTP password</span><strong>{mail.auth_required ? (mail.password_configured ? 'Configured' : 'Missing') : 'Not required'}</strong></li>
                <li><span>From</span><strong>{mail.from || 'Missing'}</strong></li>
              </ul>
              <p className="settings-hint">SMTP secrets are server-only environment variables and never appear here.</p>
              <button className="button button-secondary" type="button" disabled={working || !mail.enabled} onClick={testMail}><Send size={16} />Send test email</button>
            </>
          )}
        </aside>
      </div>
    </>
  );
}
