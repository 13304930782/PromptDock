import { FormEvent, useEffect, useMemo, useState } from 'react';
import { KeyRound, Plus, ShieldCheck } from 'lucide-react';
import { api } from '../lib/api';
import type { ManagedAdminUser } from '../types';

type UserDraft = Pick<ManagedAdminUser, 'name' | 'email' | 'role' | 'status'>;
type NewUser = {
  name: string;
  email: string;
  role: 'owner' | 'admin';
  password: string;
};

const blankUser: NewUser = { name: '', email: '', role: 'admin', password: '' };

export default function AdminUsersPage() {
  const [users, setUsers] = useState<ManagedAdminUser[]>([]);
  const [drafts, setDrafts] = useState<Record<number, UserDraft>>({});
  const [passwords, setPasswords] = useState<Record<number, string>>({});
  const [newUser, setNewUser] = useState<NewUser>(blankUser);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState('');

  const applyUsers = (nextUsers: ManagedAdminUser[]) => {
    setUsers(nextUsers);
    setDrafts(Object.fromEntries(nextUsers.map((user) => [user.id, {
      name: user.name,
      email: user.email,
      role: user.role,
      status: user.status,
    }])));
  };

  useEffect(() => {
    api<{ users: ManagedAdminUser[] }>('/admin/users')
      .then((data) => applyUsers(data.users))
      .catch((loadError) => setError(loadError instanceof Error ? loadError.message : 'Unable to load administrators.'));
  }, []);

  const activeOwners = useMemo(
    () => users.filter((user) => user.role === 'owner' && user.status === 'active').length,
    [users],
  );

  const createUser = async (event: FormEvent) => {
    event.preventDefault();
    setWorking('create');
    try {
      const data = await api<{ user: ManagedAdminUser }>('/admin/users', {
        method: 'POST',
        body: JSON.stringify(newUser),
      });
      applyUsers([...users, data.user]);
      setNewUser(blankUser);
      setNotice(`Administrator ${data.user.email} created.`);
      setError('');
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : 'Unable to create administrator.');
    } finally {
      setWorking('');
    }
  };

  const saveUser = async (id: number) => {
    const draft = drafts[id];
    if (!draft) return;
    setWorking(`save-${id}`);
    try {
      const data = await api<{ user: ManagedAdminUser }>(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(draft),
      });
      applyUsers(users.map((user) => user.id === id ? data.user : user));
      setNotice(`Administrator ${data.user.email} updated.`);
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Unable to update administrator.');
    } finally {
      setWorking('');
    }
  };

  const resetPassword = async (id: number) => {
    const password = passwords[id] || '';
    setWorking(`password-${id}`);
    try {
      const data = await api<{ message: string }>(`/admin/users/${id}/reset-password`, {
        method: 'POST',
        body: JSON.stringify({ password }),
      });
      setPasswords({ ...passwords, [id]: '' });
      setNotice(data.message);
      setError('');
    } catch (resetError) {
      setError(resetError instanceof Error ? resetError.message : 'Unable to reset password.');
    } finally {
      setWorking('');
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>Administrators</h1><p>Create accounts, manage roles, clear lockouts, and reset passwords.</p></div>
        <span className="owner-count"><ShieldCheck size={16} />{activeOwners} active owner{activeOwners === 1 ? '' : 's'}</span>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <section className="admin-card settings-card admin-create-card">
        <h2>Add administrator</h2>
        <form className="admin-create-form" onSubmit={createUser}>
          <label>Name<input value={newUser.name} onChange={(event) => setNewUser({ ...newUser, name: event.target.value })} required minLength={2} /></label>
          <label>Email<input type="email" value={newUser.email} onChange={(event) => setNewUser({ ...newUser, email: event.target.value })} required /></label>
          <label>Role
            <select value={newUser.role} onChange={(event) => setNewUser({ ...newUser, role: event.target.value as 'owner' | 'admin' })}>
              <option value="admin">Admin</option>
              <option value="owner">Owner</option>
            </select>
          </label>
          <label>Temporary password<input type="password" value={newUser.password} onChange={(event) => setNewUser({ ...newUser, password: event.target.value })} minLength={8} autoComplete="new-password" autoCapitalize="none" spellCheck={false} required /></label>
          <button className="button button-approve" type="submit" disabled={Boolean(working)}><Plus size={16} />Create</button>
        </form>
        <p className="settings-hint">Passwords need at least 8 characters with letters and numbers. The user can change it later through “Forgot password”.</p>
      </section>

      <div className="admin-users-grid">
        {users.map((user) => {
          const draft = drafts[user.id];
          if (!draft) return null;
          return (
            <article className="admin-card admin-user-card" key={user.id}>
              <div className="admin-user-summary">
                <div>
                  <strong>{user.name}</strong>
                  <span>{user.email}</span>
                </div>
                <span className={`status-badge ${user.status === 'active' ? 'approved' : 'rejected'}`}>{user.status}</span>
              </div>
              <div className="settings-form admin-user-form">
                <label>Name<input value={draft.name} onChange={(event) => setDrafts({ ...drafts, [user.id]: { ...draft, name: event.target.value } })} /></label>
                <label>Email<input type="email" value={draft.email} onChange={(event) => setDrafts({ ...drafts, [user.id]: { ...draft, email: event.target.value } })} /></label>
                <div className="settings-form-grid">
                  <label>Role
                    <select value={draft.role} onChange={(event) => setDrafts({ ...drafts, [user.id]: { ...draft, role: event.target.value as 'owner' | 'admin' } })}>
                      <option value="owner">Owner</option>
                      <option value="admin">Admin</option>
                    </select>
                  </label>
                  <label>Status
                    <select value={draft.status} onChange={(event) => setDrafts({ ...drafts, [user.id]: { ...draft, status: event.target.value as 'active' | 'disabled' } })}>
                      <option value="active">Active</option>
                      <option value="disabled">Disabled</option>
                    </select>
                  </label>
                </div>
                <button className="button button-secondary" type="button" disabled={Boolean(working)} onClick={() => saveUser(user.id)}>Save account</button>
                <div className="password-reset-row">
                  <label>New password<input type="password" value={passwords[user.id] || ''} onChange={(event) => setPasswords({ ...passwords, [user.id]: event.target.value })} minLength={8} autoComplete="new-password" autoCapitalize="none" spellCheck={false} placeholder="8+ characters" /></label>
                  <button className="button button-secondary" type="button" disabled={Boolean(working) || !(passwords[user.id] || '')} onClick={() => resetPassword(user.id)}><KeyRound size={15} />Reset</button>
                </div>
                <p className="admin-user-meta">
                  Last sign-in: {user.last_login_at ? new Date(user.last_login_at).toLocaleString() : 'Never'}
                  {user.locked_until ? ` · Locked until ${new Date(user.locked_until).toLocaleString()}` : ''}
                </p>
              </div>
            </article>
          );
        })}
      </div>
    </>
  );
}
