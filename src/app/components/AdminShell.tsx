import { LogOut, Settings, Sprout } from 'lucide-react';
import { NavLink, useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import type { AdminUser } from '../types';

export default function AdminShell({ user, children }: { user: AdminUser; children: React.ReactNode }) {
  const navigate = useNavigate();
  const logout = async () => {
    await api('/auth/logout', { method: 'POST' }).catch(() => undefined);
    navigate('/admin/login', { replace: true });
  };

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <a className="brand-lockup" href="/" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </a>
        <nav className="admin-nav" aria-label="Admin">
          <NavLink to="/admin/early-access">
            <Sprout size={18} /><span>Early Access</span>
          </NavLink>
          <NavLink to="/admin/settings">
            <Settings size={18} /><span>Settings</span>
          </NavLink>
          <button type="button" onClick={logout}>
            <LogOut size={18} /><span>Sign out</span>
          </button>
        </nav>
        <div className="admin-sidebar-user">
          <strong>{user.name}</strong>
          {user.email} · {user.role}
        </div>
      </aside>
      <div className="admin-main">{children}</div>
    </div>
  );
}
