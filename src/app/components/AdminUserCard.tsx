import { memo, useEffect, useState } from 'react';
import { KeyRound } from 'lucide-react';
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
          {user.can_issue_roll_keys && <span className="status-badge approved">Key issuer</span>}
          <span className={`status-badge ${user.status === 'active' ? 'approved' : 'rejected'}`}>{user.status}</span>
        </div>
      </div>
      <div className="settings-form admin-user-form">
        <label>Name<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label>
        <label>Email<input type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></label>
        <div className="settings-form-grid">
          <label>Role
            <select value={draft.role} onChange={(event) => {
              const role = event.target.value as 'owner' | 'admin';
              setDraft({ ...draft, role, can_issue_roll_keys: role === 'admin' && draft.can_issue_roll_keys });
            }}>
              <option value="owner">Owner</option>
              <option value="admin">Admin</option>
            </select>
          </label>
          <label>Status
            <select value={draft.status} onChange={(event) => {
              const status = event.target.value as 'active' | 'disabled';
              setDraft({ ...draft, status, can_issue_roll_keys: status === 'active' && draft.can_issue_roll_keys });
            }}>
              <option value="active">Active</option>
              <option value="disabled">Disabled</option>
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
          <span>Allow this administrator to issue 24-hour tool access keys</span>
        </label>
        <button className="button button-secondary" type="button" disabled={disabled} onClick={() => onSave(user.id, draft)}>Save account</button>
        <div className="password-reset-row">
          <label>New password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} minLength={8} autoComplete="new-password" autoCapitalize="none" spellCheck={false} placeholder="8+ characters" /></label>
          <button className="button button-secondary" type="button" disabled={disabled || !password} onClick={resetPassword}><KeyRound size={15} />Reset</button>
        </div>
        <p className="admin-user-meta">
          Last sign-in: {user.last_login_at ? new Date(user.last_login_at).toLocaleString() : 'Never'}
          {user.locked_until ? ` · Locked until ${new Date(user.locked_until).toLocaleString()}` : ''}
        </p>
      </div>
    </article>
  );
});

export default AdminUserCard;
