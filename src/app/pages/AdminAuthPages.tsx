import { FormEvent, useEffect, useState } from 'react';
import { ArrowRight } from 'lucide-react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { AdminUser } from '../types';

function AuthLayout({ children }: { children: React.ReactNode }) {
  const { locale, setLocale } = useAdminLocale();
  const zh = locale === 'zh';
  return (
    <div className="admin-login-page">
      <section className="admin-login-brand">
        <Link className="brand-lockup" to="/">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <div>
          <h1>{zh ? <>安静的工具。<br />清晰的决定。</> : <>Quiet tools.<br />Clear decisions.</>}</h1>
          <p>{zh ? '安全地审核每一位帮助 PromptDock 成长的人。' : 'Securely review the people helping PromptDock grow.'}</p>
        </div>
      </section>
      <section className="admin-login-panel">
        <button className="admin-auth-language" type="button" onClick={() => setLocale(zh ? 'en' : 'zh')}>
          {zh ? 'EN' : '中文'}
        </button>
        {children}
      </section>
    </div>
  );
}

export function AdminLoginPage({ onLogin }: { onLogin: (user: AdminUser) => void }) {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [challengeToken, setChallengeToken] = useState('');
  const [mfaCode, setMfaCode] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const finishLogin = (user: AdminUser) => {
    onLogin(user);
    navigate('/admin/early-access', { replace: true });
  };

  const submitPassword = async (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage('');
    try {
      const data = await api<
        { user: AdminUser; mfa_required?: false }
        | { mfa_required: true; challenge_token: string }
      >('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      if ('mfa_required' in data && data.mfa_required) {
        setChallengeToken(data.challenge_token);
        setPassword('');
        return;
      }
      finishLogin(data.user);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法登录。' : 'Unable to sign in.'));
    } finally {
      setLoading(false);
    }
  };

  const submitMfa = async (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage('');
    try {
      const data = await api<{
        user: AdminUser;
        recovery_code_used?: boolean;
        recovery_codes_remaining?: number;
      }>('/auth/mfa/verify-login', {
        method: 'POST',
        body: JSON.stringify({ challenge_token: challengeToken, code: mfaCode }),
      });
      finishLogin(data.user);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法验证此验证码。' : 'Unable to verify this code.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/">← {zh ? '返回 CueGrove' : 'Back to CueGrove'}</Link>
        <h2>{challengeToken ? (zh ? '验证你的身份' : 'Verify it’s you.') : (zh ? '欢迎回来' : 'Welcome back.')}</h2>
        <p>
          {challengeToken
            ? (zh ? '输入身份验证器中的六位验证码，或使用一个恢复代码。' : 'Enter the six-digit code from your authenticator, or use one recovery code.')
            : (zh ? '使用站长或管理员账号登录。' : 'Sign in with an owner or administrator account.')}
        </p>
        {message && <div className="admin-alert error" role="alert">{message}</div>}
        {challengeToken ? (
          <>
            <form className="auth-form" onSubmit={submitMfa}>
              <label>
                {zh ? '身份验证器或恢复代码' : 'Authenticator or recovery code'}
                <input
                  type="text"
                  autoComplete="one-time-code"
                  autoCapitalize="characters"
                  spellCheck={false}
                  value={mfaCode}
                  onChange={(event) => setMfaCode(event.target.value)}
                  required
                  autoFocus
                />
              </label>
              <button className="button button-submit" type="submit" disabled={loading}>
                {loading ? (zh ? '正在验证…' : 'Verifying…') : (zh ? '验证并登录' : 'Verify and sign in')}<ArrowRight size={18} />
              </button>
            </form>
            <div className="auth-links">
              <button
                className="text-button"
                type="button"
                onClick={() => {
                  setChallengeToken('');
                  setMfaCode('');
                  setMessage('');
                }}
              >
                {zh ? '使用其他账号' : 'Use a different account'}
              </button>
            </div>
          </>
        ) : (
          <>
            <form className="auth-form" onSubmit={submitPassword}>
              <label>{zh ? '邮箱' : 'Email'}<input type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>
              <label>{zh ? '密码' : 'Password'}<input type="password" autoComplete="current-password" autoCapitalize="none" spellCheck={false} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
              <button className="button button-submit" type="submit" disabled={loading}>
                {loading ? (zh ? '正在登录…' : 'Signing in…') : (zh ? '登录' : 'Sign in')}<ArrowRight size={18} />
              </button>
            </form>
            <div className="auth-links"><Link to="/admin/forgot-password">{zh ? '忘记密码？' : 'Forgot password?'}</Link></div>
          </>
        )}
      </div>
    </AuthLayout>
  );
}

export function ForgotPasswordPage() {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setLoading(true);
    try {
      const data = await api<{ message: string }>('/auth/forgot-password', {
        method: 'POST',
        body: JSON.stringify({ email }),
        timeoutMs: 130_000,
      });
      setMessage(data.message);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法发送重置邮件。' : 'Unable to send reset email.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/admin/login">← {zh ? '返回登录' : 'Back to sign in'}</Link>
        <h2>{zh ? '重置登录密码' : 'Reset access.'}</h2>
        <p>{zh ? '如果该管理员邮箱存在，我们会发送一条短期有效的重置链接。' : 'We will send a short-lived reset link if this administrator email exists.'}</p>
        {message && <div className="admin-alert">{message}</div>}
        <form className="auth-form" onSubmit={submit}>
          <label>{zh ? '邮箱' : 'Email'}<input type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>
          <button className="button button-submit" type="submit" disabled={loading}>{loading ? (zh ? '正在发送…' : 'Sending…') : (zh ? '发送重置链接' : 'Send reset link')}</button>
        </form>
      </div>
    </AuthLayout>
  );
}

export function ResetPasswordPage() {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const location = useLocation();
  const [token] = useState(() => {
    const fragmentToken = new URLSearchParams(window.location.hash.replace(/^#/, '')).get('token');
    const legacyQueryToken = new URLSearchParams(window.location.search).get('token');
    return fragmentToken || legacyQueryToken || '';
  });
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [message, setMessage] = useState('');
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!token) setMessage(zh ? '此重置链接不完整。' : 'This reset link is incomplete.');
    if (token && (location.hash || location.search)) {
      window.history.replaceState(window.history.state, '', location.pathname);
    }
  }, [location.hash, location.pathname, location.search, token, zh]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (password !== confirm) {
      setMessage(zh ? '两次输入的密码不一致。' : 'Passwords do not match.');
      return;
    }
    setLoading(true);
    try {
      const data = await api<{ message: string }>('/auth/reset-password', {
        method: 'POST',
        body: JSON.stringify({ token, password }),
      });
      setDone(true);
      setMessage(data.message);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法重置密码。' : 'Unable to reset password.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/admin/login">← {zh ? '返回登录' : 'Back to sign in'}</Link>
        <h2>{zh ? '设置新密码' : 'Choose a password.'}</h2>
        <p>{zh ? '至少使用 8 个字符，并同时包含字母和数字。' : 'Use at least 8 characters with both letters and numbers.'}</p>
        {message && <div className={`admin-alert${done ? '' : ' error'}`}>{message}</div>}
        {!done && (
          <form className="auth-form" onSubmit={submit}>
            <label>{zh ? '新密码' : 'New password'}<input type="password" autoComplete="new-password" autoCapitalize="none" spellCheck={false} minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
            <label>{zh ? '确认密码' : 'Confirm password'}<input type="password" autoComplete="new-password" autoCapitalize="none" spellCheck={false} minLength={8} value={confirm} onChange={(event) => setConfirm(event.target.value)} required /></label>
            <button className="button button-submit" type="submit" disabled={loading || !token}>{loading ? (zh ? '正在更新…' : 'Updating…') : (zh ? '更新密码' : 'Update password')}</button>
          </form>
        )}
      </div>
    </AuthLayout>
  );
}
