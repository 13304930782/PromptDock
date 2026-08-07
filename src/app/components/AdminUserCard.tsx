import { memo, useEffect, useState } from 'react';
import { KeyRound } from 'lucide-react';
import { useAdminLocale } from '../lib/adminLocale';
import type { ManagedAdminUser } from '../types';

export type AdminUserDraft = Pick<ManagedAdminUser, 'name' | 'email' | 'role' | 'status' | 'can_issue_roll_keys'>;

type Props = {
  user: ManagedAdminUser;
  disabled: boolean;
  onSave: (id: number, draft: AdminUserDraft) => Promise<void>;
  onResetPassword: (id: number, password: string) => Promise<boolean>;
};

function draftFromUser(user: ManagedAdminUser): AdminUserDraft {
  return {
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    can_issue_roll_keys: user.can_issue_roll_keys,
  };
}

const AdminUserCard = memo(function AdminUserCard({
  user,
  disabled,
  onSave,
  onResetPassword,
}: Props) {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [draft, setDraft] = useState<AdminUserDraft>(() => draftFromUser(user));
  const [password, setPassword] = useState('');

  useEffect(() => {
    setDraft(draftFromUser(user));
  }, [user]);

  const resetPassword = async () => {
    if (await onResetPassword(user.id, password)) setPassword('');
  };

  return (
    <article className="admin-card admin-user-card">
      <div className="admin-user-summary">
        <div>
          <strong>{user.name}</strong>
          <span>{user.email}</span>
        </div>
        <div className="admin-user-badges">
          {user.mfa_enabled && <span className="status-badge approved">MFA</span>}
          {user.can_issue_roll_keys && <span className="status-badge approved">{zh ? '密钥签发人' : 'Key issuer'}</span>}
          <span className={`status-badge ${user.status === 'active' ? 'approved' : 'rejected'}`}>{zh ? (user.status === 'active' ? '有效' : '已停用') : user.status}</span>
        </div>
      </div>
      <div className="settings-form admin-user-form">
        <label>{zh ? '姓名' : 'Name'}<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label>
        <label>{zh ? '邮箱' : 'Email'}<input type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></label>
        <div className="settings-form-grid">
          <label>{zh ? '角色' : 'Role'}
            <select value={draft.role} onChange={(event) => {
              const role = event.target.value as 'owner' | 'admin';
              setDraft({ ...draft, role, can_issue_roll_keys: role === 'admin' && draft.can_issue_roll_keys });
            }}>
              <option value="owner">{zh ? '站长' : 'Owner'}</option>
              <option value="admin">{zh ? '管理员' : 'Admin'}</option>
            </select>
          </label>
          <label>{zh ? '状态' : 'Status'}
            <select value={draft.status} onChange={(event) => {
              const status = event.target.value as 'active' | 'disabled';
              setDraft({ ...draft, status, can_issue_roll_keys: status === 'active' && draft.can_issue_roll_keys });
            }}>
              <option value="active">{zh ? '有效' : 'Active'}</option>
              <option value="disabled">{zh ? '已停用' : 'Disabled'}</option>
            </select>
          </label>
        </div>
        <label className="toggle-label admin-permission-toggle">
          <input
            type="checkbox"
            checked={draft.can_issue_roll_keys}
            disabled={draft.role !== 'admin' || draft.status !== 'active'}
            onChange={(event) => setDraft({ ...draft, can_issue_roll_keys: event.target.checked })}
          />
          <span>{zh ? '允许此管理员签发 24 小时工具访问密钥' : 'Allow this administrator to issue 24-hour tool access keys'}</span>
        </label>
        <button className="button button-secondary" type="button" disabled={disabled} onClick={() => onSave(user.id, draft)}>{zh ? '保存账号' : 'Save account'}</button>
        <div className="password-reset-row">
          <label>{zh ? '新密码' : 'New password'}<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} minLength={8} autoComplete="new-password" autoCapitalize="none" spellCheck={false} placeholder={zh ? '至少 8 个字符' : '8+ characters'} /></label>
          <button className="button button-secondary" type="button" disabled={disabled || !password} onClick={resetPassword}><KeyRound size={15} />{zh ? '重置' : 'Reset'}</button>
        </div>
        <p className="admin-user-meta">
          {zh ? '上次登录' : 'Last sign-in'}：{user.last_login_at ? new Date(user.last_login_at).toLocaleString(zh ? 'zh-CN' : 'en-US') : (zh ? '从未登录' : 'Never')}
          {user.locked_until ? ` · ${zh ? '锁定至' : 'Locked until'} ${new Date(user.locked_until).toLocaleString(zh ? 'zh-CN' : 'en-US')}` : ''}
        </p>
      </div>
    </article>
  );
});

export default AdminUserCard;
