import { FormEvent, useEffect, useState } from 'react';
import { ArrowRight } from 'lucide-react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import type { AdminUser } from '../types';

function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="admin-login-page">
      <section className="admin-login-brand">
        <Link className="brand-lockup" to="/">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <div>
          <h1>Quiet tools.<br />Clear decisions.</h1>
          <p>Securely review the people helping PromptDock grow.</p>
        </div>
      </section>
      <section className="admin-login-panel">{children}</section>
    </div>
  );
}

export function AdminLoginPage({ onLogin }: { onLogin: (user: AdminUser) => void }) {
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
      setMessage(error instanceof Error ? error.message : 'Unable to sign in.');
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
      setMessage(error instanceof Error ? error.message : 'Unable to verify this code.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/">← Back to CueGrove</Link>
        <h2>{challengeToken ? 'Verify it’s you.' : 'Welcome back.'}</h2>
        <p>
          {challengeToken
            ? 'Enter the six-digit code from your authenticator, or use one recovery code.'
            : 'Sign in with an owner or administrator account.'}
        </p>
        {message && <div className="admin-alert error" role="alert">{message}</div>}
        {challengeToken ? (
          <>
            <form className="auth-form" onSubmit={submitMfa}>
              <label>
                Authenticator or recovery code
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
                {loading ? 'Verifying…' : 'Verify and sign in'}<ArrowRight size={18} />
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
                Use a different account
              </button>
            </div>
          </>
        ) : (
          <>
            <form className="auth-form" onSubmit={submitPassword}>
              <label>Email<input type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>
              <label>Password<input type="password" autoComplete="current-password" autoCapitalize="none" spellCheck={false} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
              <button className="button button-submit" type="submit" disabled={loading}>
                {loading ? 'Signing in…' : 'Sign in'}<ArrowRight size={18} />
              </button>
            </form>
            <div className="auth-links"><Link to="/admin/forgot-password">Forgot password?</Link></div>
          </>
        )}
      </div>
    </AuthLayout>
  );
}

export function ForgotPasswordPage() {
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
      setMessage(error instanceof Error ? error.message : 'Unable to send reset email.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/admin/login">← Back to sign in</Link>
        <h2>Reset access.</h2>
        <p>We will send a short-lived reset link if this administrator email exists.</p>
        {message && <div className="admin-alert">{message}</div>}
        <form className="auth-form" onSubmit={submit}>
          <label>Email<input type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} required /></label>
          <button className="button button-submit" type="submit" disabled={loading}>{loading ? 'Sending…' : 'Send reset link'}</button>
        </form>
      </div>
    </AuthLayout>
  );
}

export function ResetPasswordPage() {
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
    if (!token) setMessage('This reset link is incomplete.');
    if (token && (location.hash || location.search)) {
      window.history.replaceState(window.history.state, '', location.pathname);
    }
  }, [location.hash, location.pathname, location.search, token]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (password !== confirm) {
      setMessage('Passwords do not match.');
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
      setMessage(error instanceof Error ? error.message : 'Unable to reset password.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="auth-card">
        <Link to="/admin/login">← Back to sign in</Link>
        <h2>Choose a password.</h2>
        <p>Use at least 8 characters with both letters and numbers.</p>
        {message && <div className={`admin-alert${done ? '' : ' error'}`}>{message}</div>}
        {!done && (
          <form className="auth-form" onSubmit={submit}>
            <label>New password<input type="password" autoComplete="new-password" autoCapitalize="none" spellCheck={false} minLength={8} value={password} onChange={(event) => setPassword(event.target.value)} required /></label>
            <label>Confirm password<input type="password" autoComplete="new-password" autoCapitalize="none" spellCheck={false} minLength={8} value={confirm} onChange={(event) => setConfirm(event.target.value)} required /></label>
            <button className="button button-submit" type="submit" disabled={loading || !token}>{loading ? 'Updating…' : 'Update password'}</button>
          </form>
        )}
      </div>
    </AuthLayout>
  );
}
