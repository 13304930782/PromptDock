import { FormEvent, useEffect, useState } from 'react';
import { Copy, Download, KeyRound, ShieldCheck, Smartphone } from 'lucide-react';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
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

function formatDate(value: string | null, locale: 'zh' | 'en') {
  if (!value) return locale === 'zh' ? '未启用' : 'Not enabled';
  return new Intl.DateTimeFormat(locale === 'zh' ? 'zh-CN' : 'en-US', {
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
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
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
    .catch((loadError) => setError(loadError instanceof Error ? loadError.message : (zh ? '无法加载安全设置。' : 'Unable to load security settings.')));

  useEffect(() => {
    loadStatus();
  }, [zh]);

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
      setError(setupError instanceof Error ? setupError.message : (zh ? '无法开始设置多因素认证。' : 'Unable to start MFA setup.'));
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
      setNotice(zh ? '多因素认证已启用，请立即保存下方的恢复代码。' : 'Multi-factor authentication is enabled. Save the recovery codes below now.');
    } catch (enableError) {
      setError(enableError instanceof Error ? enableError.message : (zh ? '无法启用多因素认证。' : 'Unable to enable MFA.'));
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
      setNotice(zh ? '新的恢复代码已生成，之前的恢复代码均已失效。' : 'New recovery codes created. All previous recovery codes are now invalid.');
    } catch (regenerateError) {
      setError(regenerateError instanceof Error ? regenerateError.message : (zh ? '无法生成新的恢复代码。' : 'Unable to create new recovery codes.'));
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
      setNotice(zh ? '此账号的多因素认证已关闭。' : 'Multi-factor authentication is disabled for this account.');
    } catch (disableError) {
      setError(disableError instanceof Error ? disableError.message : (zh ? '无法关闭多因素认证。' : 'Unable to disable MFA.'));
    } finally {
      setWorking('');
    }
  };

  const copyRecoveryCodes = async () => {
    try {
      await navigator.clipboard.writeText(recoveryCodes.join('\n'));
      setNotice(zh ? '恢复代码已复制。' : 'Recovery codes copied.');
    } catch {
      setError(zh ? '无法自动复制，请手动选中并复制下方代码。' : 'Unable to copy automatically. Select and copy the codes below.');
    }
  };

  const downloadRecoveryCodes = () => {
    const body = [
      zh ? 'CueGrove 管理员恢复代码' : 'CueGrove administrator recovery codes',
      `${zh ? '账号' : 'Account'}: ${user.email}`,
      `${zh ? '生成时间' : 'Created'}: ${new Date().toISOString()}`,
      '',
      ...recoveryCodes,
      '',
      zh ? '每个代码只能使用一次。请将此文件保存在与密码分离的安全位置。' : 'Each code works once. Store this file somewhere private and separate from your password.',
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
          <h1>{zh ? '安全' : 'Security'}</h1>
          <p>{zh ? '使用身份验证器和一次性恢复代码保护管理员账号。' : 'Protect your administrator account with an authenticator and one-time recovery codes.'}</p>
        </div>
        {status && (
          <span className={`security-status ${status.enabled ? 'enabled' : ''}`}>
            <ShieldCheck size={16} />MFA {status.enabled ? (zh ? '已启用' : 'enabled') : (zh ? '未启用' : 'off')}
          </span>
        )}
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <div className="settings-console">
        <section className="admin-card settings-card">
          <div className="settings-heading">
            <div>
              <h2>{zh ? '身份验证器应用' : 'Authenticator app'}</h2>
              <p>{zh ? '可使用 Google Authenticator、Microsoft Authenticator、1Password 或其他兼容 TOTP 的应用。' : 'Use Google Authenticator, Microsoft Authenticator, 1Password, or any TOTP-compatible app.'}</p>
            </div>
            <span className={`settings-source ${status?.enabled ? 'ready' : ''}`}>
              <Smartphone size={14} />{status?.enabled ? (zh ? '已保护' : 'Protected') : (zh ? '可启用' : 'Available')}
            </span>
          </div>

          {status && !status.enabled && !setup && (
            <div className="mfa-intro">
              <div>
                <strong>{zh ? '为登录添加第二重验证' : 'Add a second proof at sign-in'}</strong>
                <p>{zh ? '密码仍是第一重验证，创建管理员会话前还需要一个新的六位验证码。' : 'Your password remains the first factor. A fresh six-digit code is required before an administrator session is created.'}</p>
              </div>
              <button className="button button-approve" type="button" onClick={startSetup} disabled={Boolean(working)}>
                <KeyRound size={16} />{working === 'setup' ? (zh ? '正在准备…' : 'Preparing…') : (zh ? '设置多因素认证' : 'Set up MFA')}
              </button>
            </div>
          )}

          {setup && (
            <div className="mfa-setup">
              <div className="mfa-qr">
                <img src={setup.qr_data_url} alt={zh ? 'CueGrove 管理员多因素认证二维码' : 'QR code for CueGrove administrator multi-factor authentication'} />
              </div>
              <div className="mfa-setup-copy">
                <span className="eyebrow">{zh ? '第 1 步' : 'Step 1'}</span>
                <h3>{zh ? '扫描二维码' : 'Scan the QR code'}</h3>
                <p>{zh ? '打开身份验证器应用，扫描此二维码添加账号。' : 'Open your authenticator app and add an account by scanning this code.'}</p>
                <details>
                  <summary>{zh ? '无法扫描？手动输入设置密钥' : 'Can’t scan it? Enter the setup key'}</summary>
                  <code>{setup.secret}</code>
                </details>
                <form className="settings-form mfa-verify-form" onSubmit={enableMfa}>
                  <span className="eyebrow">{zh ? '第 2 步' : 'Step 2'}</span>
                  <label>
                    {zh ? '输入当前六位验证码' : 'Enter the current six-digit code'}
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
                  <p className="settings-hint">{zh ? `此设置将在 ${setup.expires_in_minutes} 分钟后过期。` : `This setup expires in ${setup.expires_in_minutes} minutes.`}</p>
                  <div className="settings-actions">
                    <button className="button button-approve" type="submit" disabled={Boolean(working)}>
                      {working === 'enable' ? (zh ? '正在验证…' : 'Verifying…') : (zh ? '验证并启用' : 'Verify and enable')}
                    </button>
                    <button className="button button-secondary" type="button" onClick={() => setSetup(null)} disabled={Boolean(working)}>
                      {zh ? '取消' : 'Cancel'}
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
                <strong>{zh ? '多因素认证已启用' : 'Multi-factor authentication is active'}</strong>
                <p>{zh ? `启用时间 ${formatDate(status.enabled_at, locale)} · 剩余 ${status.recovery_codes_remaining} 个恢复代码` : `Enabled ${formatDate(status.enabled_at, locale)} · ${status.recovery_codes_remaining} recovery codes remaining`}</p>
              </div>
            </div>
          )}
        </section>

        {recoveryCodes.length > 0 && (
          <section className="admin-card settings-card recovery-card">
            <div className="settings-heading">
              <div>
                <h2>{zh ? '保存恢复代码' : 'Save your recovery codes'}</h2>
                <p>{zh ? '每个代码只能使用一次，离开此页面后不会再次显示。' : 'Each code works once. They will not be shown again after you leave this page.'}</p>
              </div>
              <span className="settings-source ready">{recoveryCodes.length} {zh ? '个代码' : 'codes'}</span>
            </div>
            <div className="recovery-code-grid" aria-label={zh ? '一次性恢复代码' : 'One-time recovery codes'}>
              {recoveryCodes.map((code) => <code key={code}>{code}</code>)}
            </div>
            <div className="settings-actions">
              <button className="button button-secondary" type="button" onClick={copyRecoveryCodes}><Copy size={16} />{zh ? '全部复制' : 'Copy all'}</button>
              <button className="button button-secondary" type="button" onClick={downloadRecoveryCodes}><Download size={16} />{zh ? '下载文本文件' : 'Download text file'}</button>
            </div>
          </section>
        )}

        {status?.enabled && (
          <section className="mfa-management-grid">
            <div className="admin-card settings-card">
              <h2>{zh ? '更换恢复代码' : 'Replace recovery codes'}</h2>
              <p className="settings-description">{zh ? '生成十个新代码，并立即使之前的所有恢复代码失效。' : 'Create ten new codes and immediately invalidate every previous recovery code.'}</p>
              <form className="settings-form" onSubmit={regenerateCodes}>
                <label>
                  {zh ? '当前身份验证器代码' : 'Current authenticator code'}
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
                <p className="settings-hint">{zh ? '请使用尚未用于登录的新验证码。' : 'Use a fresh code that has not already been used to sign in.'}</p>
                <button className="button button-secondary" type="submit" disabled={Boolean(working)}>
                  {working === 'regenerate' ? (zh ? '正在生成…' : 'Creating…') : (zh ? '生成新的恢复代码' : 'Create new recovery codes')}
                </button>
              </form>
            </div>

            <div className="admin-card settings-card mfa-danger-card">
              <h2>{zh ? '关闭多因素认证' : 'Disable MFA'}</h2>
              <p className="settings-description">{zh ? '这将移除身份验证器，并使此账号的所有恢复代码失效。' : 'This removes the authenticator and invalidates all recovery codes for your account.'}</p>
              <form className="settings-form" onSubmit={disableMfa}>
                <label>
                  {zh ? '当前密码' : 'Current password'}
                  <input type="password" autoComplete="current-password" value={disablePassword} onChange={(event) => setDisablePassword(event.target.value)} required />
                </label>
                <label>
                  {zh ? '身份验证器或恢复代码' : 'Authenticator or recovery code'}
                  <input type="text" autoComplete="one-time-code" autoCapitalize="characters" spellCheck={false} value={disableCode} onChange={(event) => setDisableCode(event.target.value)} required />
                </label>
                <button className="button button-reject" type="submit" disabled={Boolean(working)}>
                  {working === 'disable' ? (zh ? '正在关闭…' : 'Disabling…') : (zh ? '关闭多因素认证' : 'Disable multi-factor authentication')}
                </button>
              </form>
            </div>
          </section>
        )}
      </div>
    </>
  );
}
