import { memo, useEffect, useState } from 'react';
import { KeyRound } from 'lucide-react';
import type { ManagedAdminUser } from '../types';

export type AdminUserDraft = Pick<ManagedAdminUser, 'name' | 'email' | 'role' | 'status'>;

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
        <span className={`status-badge ${user.status === 'active' ? 'approved' : 'rejected'}`}>{user.status}</span>
      </div>
      <div className="settings-form admin-user-form">
        <label>Name<input value={draft.name} onChange={(event) => setDraft({ ...draft, name: event.target.value })} /></label>
        <label>Email<input type="email" value={draft.email} onChange={(event) => setDraft({ ...draft, email: event.target.value })} /></label>
        <div className="settings-form-grid">
          <label>Role
            <select value={draft.role} onChange={(event) => setDraft({ ...draft, role: event.target.value as 'owner' | 'admin' })}>
              <option value="owner">Owner</option>
              <option value="admin">Admin</option>
            </select>
          </label>
          <label>Status
            <select value={draft.status} onChange={(event) => setDraft({ ...draft, status: event.target.value as 'active' | 'disabled' })}>
              <option value="active">Active</option>
              <option value="disabled">Disabled</option>
            </select>
          </label>
        </div>
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
