import { ClipboardList, KeyRound, LogOut, Settings, ShieldCheck, Sprout, Users } from 'lucide-react';
import { NavLink, useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { AdminUser } from '../types';

export default function AdminShell({ user, children }: { user: AdminUser; children: React.ReactNode }) {
  const navigate = useNavigate();
  const { locale, setLocale } = useAdminLocale();
  const zh = locale === 'zh';
  const logout = async () => {
    await api('/auth/logout', { method: 'POST' }).catch(() => undefined);
    navigate('/admin/login', { replace: true });
  };

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <a className="brand-lockup" href="/" aria-label={zh ? 'CueGrove 首页' : 'CueGrove home'}>
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </a>
        <nav className="admin-nav" aria-label={zh ? '后台管理' : 'Admin'}>
          <NavLink to="/admin/early-access">
            <Sprout size={18} /><span>{zh ? '内测申请' : 'Early Access'}</span>
          </NavLink>
          <NavLink to="/admin/settings">
            <Settings size={18} /><span>{zh ? '设置' : 'Settings'}</span>
          </NavLink>
          <NavLink to="/admin/security">
            <ShieldCheck size={18} /><span>{zh ? '安全' : 'Security'}</span>
          </NavLink>
          {(user.role === 'owner' || user.can_issue_roll_keys) && (
            <NavLink to="/admin/roll-access">
              <KeyRound size={18} /><span>{zh ? '工具密钥' : 'Tool keys'}</span>
            </NavLink>
          )}
          {user.role === 'owner' && (
            <NavLink to="/admin/users">
              <Users size={18} /><span>{zh ? '管理员' : 'Administrators'}</span>
            </NavLink>
          )}
          {user.role === 'owner' && (
            <NavLink to="/admin/feedback">
              <ClipboardList size={18} /><span>{zh ? '用户反馈' : 'Feedback'}</span>
            </NavLink>
          )}
          <button type="button" onClick={logout}>
            <LogOut size={18} /><span>{zh ? '退出登录' : 'Sign out'}</span>
          </button>
        </nav>
        <button
          className="admin-language-switch"
          type="button"
          onClick={() => setLocale(zh ? 'en' : 'zh')}
          aria-label={zh ? 'Switch admin interface to English' : '将后台切换为中文'}
        >
          <span className={zh ? 'active' : ''}>中文</span>
          <span className={!zh ? 'active' : ''}>EN</span>
        </button>
        <div className="admin-sidebar-user">
          <strong>{user.name}</strong>
          {user.email} · {zh ? (user.role === 'owner' ? '站长' : '管理员') : user.role}
        </div>
      </aside>
      <div className="admin-main">{children}</div>
    </div>
  );
}
