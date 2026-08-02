import {
  lazy,
  Suspense,
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router';
import { api } from './lib/api';
import type { AdminUser } from './types';

const AdminShell = lazy(() => import('./components/AdminShell'));
const AdminApplicationsPage = lazy(() => import('./pages/AdminApplicationsPage'));
const AdminSecurityPage = lazy(() => import('./pages/AdminSecurityPage'));
const AdminSettingsPage = lazy(() => import('./pages/AdminSettingsPage'));
const AdminUsersPage = lazy(() => import('./pages/AdminUsersPage'));
const AdminFeedbackPage = lazy(() => import('./pages/AdminFeedbackPage'));
const FeedbackPage = lazy(() => import('./pages/FeedbackPage'));
const FeedbackInfoPage = lazy(() => import('./pages/FeedbackInfoPage'));
const PrivacyPromisePage = lazy(() => import('./pages/PrivacyPromisePage'));
const PublicSite = lazy(() => import('./pages/PublicSite'));
const SecurityCommitmentPage = lazy(() => import('./pages/SecurityCommitmentPage'));

const AdminLoginPage = lazy(async () => {
  const module = await import('./pages/AdminAuthPages');
  return { default: module.AdminLoginPage };
});

const ForgotPasswordPage = lazy(async () => {
  const module = await import('./pages/AdminAuthPages');
  return { default: module.ForgotPasswordPage };
});

const ResetPasswordPage = lazy(async () => {
  const module = await import('./pages/AdminAuthPages');
  return { default: module.ResetPasswordPage };
});

function RouteFallback() {
  return (
    <div className="route-loading" role="status" aria-live="polite">
      <span>CueGrove</span>
    </div>
  );
}

function ProtectedAdmin({
  user,
  checking,
  children,
}: {
  user: AdminUser | null;
  checking: boolean;
  children: ReactNode;
}) {
  if (checking) return <div className="admin-page empty-admin">Checking administrator session…</div>;
  if (!user) return <Navigate to="/admin/login" replace />;
  return <AdminShell user={user}>{children}</AdminShell>;
}

export default function App() {
  const location = useLocation();
  const isAdminArea = location.pathname === '/admin' || location.pathname.startsWith('/admin/');
  const [user, setUser] = useState<AdminUser | null>(null);
  const [checking, setChecking] = useState(isAdminArea);

  const checkSession = useCallback(async () => {
    try {
      const data = await api<{ user: AdminUser }>('/auth/me');
      setUser(data.user);
    } catch {
      setUser(null);
    } finally {
      setChecking(false);
    }
  }, []);

  useEffect(() => {
    if (!isAdminArea) {
      setChecking(false);
      return;
    }

    setChecking(true);
    checkSession();
  }, [checkSession, isAdminArea]);

  return (
    <Suspense fallback={<RouteFallback />}>
      <Routes>
        <Route path="/" element={<PublicSite />} />
        <Route path="/privacy-promise" element={<PrivacyPromisePage />} />
        <Route path="/security" element={<SecurityCommitmentPage />} />
        <Route path="/feedback/:token" element={<FeedbackPage />} />
        <Route path="/feedback/portal" element={<FeedbackPage />} />
        <Route path="/feedback" element={<FeedbackInfoPage />} />
        <Route path="/admin/login" element={user ? <Navigate to="/admin/early-access" replace /> : <AdminLoginPage onLogin={setUser} />} />
        <Route path="/admin/forgot-password" element={<ForgotPasswordPage />} />
        <Route path="/admin/reset-password" element={<ResetPasswordPage />} />
        <Route path="/admin/early-access" element={<ProtectedAdmin user={user} checking={checking}><AdminApplicationsPage user={user!} /></ProtectedAdmin>} />
        <Route path="/admin/settings" element={<ProtectedAdmin user={user} checking={checking}><AdminSettingsPage user={user!} /></ProtectedAdmin>} />
        <Route path="/admin/security" element={<ProtectedAdmin user={user} checking={checking}><AdminSecurityPage user={user!} onUserChange={setUser} /></ProtectedAdmin>} />
        <Route path="/admin/users" element={<ProtectedAdmin user={user} checking={checking}>{user?.role === 'owner' ? <AdminUsersPage /> : <Navigate to="/admin/early-access" replace />}</ProtectedAdmin>} />
        <Route path="/admin/feedback" element={<ProtectedAdmin user={user} checking={checking}>{user?.role === 'owner' ? <AdminFeedbackPage /> : <Navigate to="/admin/early-access" replace />}</ProtectedAdmin>} />
        <Route path="/admin" element={<Navigate to="/admin/early-access" replace />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  );
}
