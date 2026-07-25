import { useCallback, useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import AdminShell from './components/AdminShell';
import { api } from './lib/api';
import AdminApplicationsPage from './pages/AdminApplicationsPage';
import { AdminLoginPage, ForgotPasswordPage, ResetPasswordPage } from './pages/AdminAuthPages';
import AdminSettingsPage from './pages/AdminSettingsPage';
import PublicSite from './pages/PublicSite';
import type { AdminUser } from './types';

function ProtectedAdmin({
  user,
  checking,
  children,
}: {
  user: AdminUser | null;
  checking: boolean;
  children: React.ReactNode;
}) {
  if (checking) return <div className="admin-page empty-admin">Checking administrator session…</div>;
  if (!user) return <Navigate to="/admin/login" replace />;
  return <AdminShell user={user}>{children}</AdminShell>;
}

export default function App() {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [checking, setChecking] = useState(true);

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
    checkSession();
  }, [checkSession]);

  return (
    <Routes>
      <Route path="/" element={<PublicSite />} />
      <Route path="/admin/login" element={user ? <Navigate to="/admin/early-access" replace /> : <AdminLoginPage onLogin={setUser} />} />
      <Route path="/admin/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/admin/reset-password" element={<ResetPasswordPage />} />
      <Route path="/admin/early-access" element={<ProtectedAdmin user={user} checking={checking}><AdminApplicationsPage /></ProtectedAdmin>} />
      <Route path="/admin/settings" element={<ProtectedAdmin user={user} checking={checking}><AdminSettingsPage /></ProtectedAdmin>} />
      <Route path="/admin" element={<Navigate to="/admin/early-access" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
