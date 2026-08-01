import { FormEvent, useEffect, useState } from 'react';
import { Copy, Download, KeyRound, ShieldCheck, Smartphone } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminUser } from '../types';

type MfaStatus = {
  enabled: boolean;
  enabled_at: string | null;
  recovery_codes_remaining: number;
};

type MfaSetup = {
  secret: string;
  otpauth_uri: string;
  qr_data_url: string;
  expires_in_minutes: number;
};

function formatDate(value: string | null) {
  if (!value) return 'Not enabled';
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
}

export default function AdminSecurityPage({
  user,
  onUserChange,
}: {
  user: AdminUser;
  onUserChange: (user: AdminUser) => void;
}) {
  const [status, setStatus] = useState<MfaStatus | null>(null);
  const [setup, setSetup] = useState<MfaSetup | null>(null);
  const [setupCode, setSetupCode] = useState('');
  const [recoveryCodes, setRecoveryCodes] = useState<string[]>([]);
  const [regenerateCode, setRegenerateCode] = useState('');
  const [disablePassword, setDisablePassword] = useState('');
  const [disableCode, setDisableCode] = useState('');
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState('');

  const loadStatus = () => api<MfaStatus>('/auth/mfa/status')
    .then(setStatus)
    .catch((loadError) => setError(loadError instanceof Error ? loadError.message : 'Unable to load security settings.'));

  useEffect(() => {
    loadStatus();
  }, []);

  const startSetup = async () => {
    setWorking('setup');
    setNotice('');
    setError('');
    setRecoveryCodes([]);
    try {
      const data = await api<MfaSetup>('/auth/mfa/setup', { method: 'POST' });
      setSetup(data);
      setSetupCode('');
    } catch (setupError) {
      setError(setupError instanceof Error ? setupError.message : 'Unable to start MFA setup.');
    } finally {
      setWorking('');
    }
  };

  const enableMfa = async (event: FormEvent) => {
    event.preventDefault();
    setWorking('enable');
    setError('');
    try {
      const data = await api<{ user: AdminUser; recovery_codes: string[] }>('/auth/mfa/enable', {
        method: 'POST',
        body: JSON.stringify({ code: setupCode }),
      });
      setRecoveryCodes(data.recovery_codes);
      setSetup(null);
      setSetupCode('');
      setStatus({
        enabled: true,
        enabled_at: new Date().toISOString(),
        recovery_codes_remaining: data.recovery_codes.length,
      });
      onUserChange(data.user);
      setNotice('Multi-factor authentication is enabled. Save the recovery codes below now.');
    } catch (enableError) {
      setError(enableError instanceof Error ? enableError.message : 'Unable to enable MFA.');
    } finally {
      setWorking('');
    }
  };

  const regenerateCodes = async (event: FormEvent) => {
    event.preventDefault();
    setWorking('regenerate');
    setError('');
    try {
      const data = await api<{ recovery_codes: string[] }>('/auth/mfa/recovery-codes', {
        method: 'POST',
        body: JSON.stringify({ code: regenerateCode }),
      });
      setRecoveryCodes(data.recovery_codes);
      setRegenerateCode('');
      setStatus((current) => current ? { ...current, recovery_codes_remaining: data.recovery_codes.length } : current);
      setNotice('New recovery codes created. All previous recovery codes are now invalid.');
    } catch (regenerateError) {
      setError(regenerateError instanceof Error ? regenerateError.message : 'Unable to create new recovery codes.');
    } finally {
      setWorking('');
    }
  };

  const disableMfa = async (event: FormEvent) => {
    event.preventDefault();
    setWorking('disable');
    setError('');
    try {
      const data = await api<{ user: AdminUser }>('/auth/mfa', {
        method: 'DELETE',
        body: JSON.stringify({ password: disablePassword, code: disableCode }),
      });
      setStatus({ enabled: false, enabled_at: null, recovery_codes_remaining: 0 });
      setRecoveryCodes([]);
      setDisablePassword('');
      setDisableCode('');
      onUserChange(data.user);
      setNotice('Multi-factor authentication is disabled for this account.');
    } catch (disableError) {
      setError(disableError instanceof Error ? disableError.message : 'Unable to disable MFA.');
    } finally {
      setWorking('');
    }
  };

  const copyRecoveryCodes = async () => {
    try {
      await navigator.clipboard.writeText(recoveryCodes.join('\n'));
      setNotice('Recovery codes copied.');
    } catch {
      setError('Unable to copy automatically. Select and copy the codes below.');
    }
  };

  const downloadRecoveryCodes = () => {
    const body = [
      'CueGrove administrator recovery codes',
      `Account: ${user.email}`,
      `Created: ${new Date().toISOString()}`,
      '',
      ...recoveryCodes,
      '',
      'Each code works once. Store this file somewhere private and separate from your password.',
    ].join('\n');
    const url = URL.createObjectURL(new Blob([body], { type: 'text/plain;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = 'cuegrove-recovery-codes.txt';
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <>
      <div className="admin-topline">
        <div>
          <h1>Security</h1>
          <p>Protect your administrator account with an authenticator and one-time recovery codes.</p>
        </div>
        {status && (
          <span className={`security-status ${status.enabled ? 'enabled' : ''}`}>
            <ShieldCheck size={16} />MFA {status.enabled ? 'enabled' : 'off'}
          </span>
        )}
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <div className="settings-console">
        <section className="admin-card settings-card">
          <div className="settings-heading">
            <div>
              <h2>Authenticator app</h2>
              <p>Use Google Authenticator, Microsoft Authenticator, 1Password, or any TOTP-compatible app.</p>
            </div>
            <span className={`settings-source ${status?.enabled ? 'ready' : ''}`}>
              <Smartphone size={14} />{status?.enabled ? 'Protected' : 'Available'}
            </span>
          </div>

          {status && !status.enabled && !setup && (
            <div className="mfa-intro">
              <div>
                <strong>Add a second proof at sign-in</strong>
                <p>Your password remains the first factor. A fresh six-digit code is required before an administrator session is created.</p>
              </div>
              <button className="button button-approve" type="button" onClick={startSetup} disabled={Boolean(working)}>
                <KeyRound size={16} />{working === 'setup' ? 'Preparing…' : 'Set up MFA'}
              </button>
            </div>
          )}

          {setup && (
            <div className="mfa-setup">
              <div className="mfa-qr">
                <img src={setup.qr_data_url} alt="QR code for CueGrove administrator multi-factor authentication" />
              </div>
              <div className="mfa-setup-copy">
                <span className="eyebrow">Step 1</span>
                <h3>Scan the QR code</h3>
                <p>Open your authenticator app and add an account by scanning this code.</p>
                <details>
                  <summary>Can’t scan it? Enter the setup key</summary>
                  <code>{setup.secret}</code>
                </details>
                <form className="settings-form mfa-verify-form" onSubmit={enableMfa}>
                  <span className="eyebrow">Step 2</span>
                  <label>
                    Enter the current six-digit code
                    <input
                      type="text"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      pattern="[0-9]{6}"
                      maxLength={6}
                      value={setupCode}
                      onChange={(event) => setSetupCode(event.target.value.replace(/\D/g, ''))}
                      required
                    />
                  </label>
                  <p className="settings-hint">This setup expires in {setup.expires_in_minutes} minutes.</p>
                  <div className="settings-actions">
                    <button className="button button-approve" type="submit" disabled={Boolean(working)}>
                      {working === 'enable' ? 'Verifying…' : 'Verify and enable'}
                    </button>
                    <button className="button button-secondary" type="button" onClick={() => setSetup(null)} disabled={Boolean(working)}>
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}

          {status?.enabled && (
            <div className="mfa-enabled-summary">
              <ShieldCheck size={26} />
              <div>
                <strong>Multi-factor authentication is active</strong>
                <p>Enabled {formatDate(status.enabled_at)} · {status.recovery_codes_remaining} recovery codes remaining</p>
              </div>
            </div>
          )}
        </section>

        {recoveryCodes.length > 0 && (
          <section className="admin-card settings-card recovery-card">
            <div className="settings-heading">
              <div>
                <h2>Save your recovery codes</h2>
                <p>Each code works once. They will not be shown again after you leave this page.</p>
              </div>
              <span className="settings-source ready">{recoveryCodes.length} codes</span>
            </div>
            <div className="recovery-code-grid" aria-label="One-time recovery codes">
              {recoveryCodes.map((code) => <code key={code}>{code}</code>)}
            </div>
            <div className="settings-actions">
              <button className="button button-secondary" type="button" onClick={copyRecoveryCodes}><Copy size={16} />Copy all</button>
              <button className="button button-secondary" type="button" onClick={downloadRecoveryCodes}><Download size={16} />Download text file</button>
            </div>
          </section>
        )}

        {status?.enabled && (
          <section className="mfa-management-grid">
            <div className="admin-card settings-card">
              <h2>Replace recovery codes</h2>
              <p className="settings-description">Create ten new codes and immediately invalidate every previous recovery code.</p>
              <form className="settings-form" onSubmit={regenerateCodes}>
                <label>
                  Current authenticator code
                  <input
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    pattern="[0-9]{6}"
                    maxLength={6}
                    value={regenerateCode}
                    onChange={(event) => setRegenerateCode(event.target.value.replace(/\D/g, ''))}
                    required
                  />
                </label>
                <p className="settings-hint">Use a fresh code that has not already been used to sign in.</p>
                <button className="button button-secondary" type="submit" disabled={Boolean(working)}>
                  {working === 'regenerate' ? 'Creating…' : 'Create new recovery codes'}
                </button>
              </form>
            </div>

            <div className="admin-card settings-card mfa-danger-card">
              <h2>Disable MFA</h2>
              <p className="settings-description">This removes the authenticator and invalidates all recovery codes for your account.</p>
              <form className="settings-form" onSubmit={disableMfa}>
                <label>
                  Current password
                  <input type="password" autoComplete="current-password" value={disablePassword} onChange={(event) => setDisablePassword(event.target.value)} required />
                </label>
                <label>
                  Authenticator or recovery code
                  <input type="text" autoComplete="one-time-code" autoCapitalize="characters" spellCheck={false} value={disableCode} onChange={(event) => setDisableCode(event.target.value)} required />
                </label>
                <button className="button button-reject" type="submit" disabled={Boolean(working)}>
                  {working === 'disable' ? 'Disabling…' : 'Disable multi-factor authentication'}
                </button>
              </form>
            </div>
          </section>
        )}
      </div>
    </>
  );
}
