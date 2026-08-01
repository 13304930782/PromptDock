import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { Plus, ShieldCheck } from 'lucide-react';
import AdminUserCard, { type AdminUserDraft } from '../components/AdminUserCard';
import { api } from '../lib/api';
import type { ManagedAdminUser } from '../types';

type NewUser = {
  name: string;
  email: string;
  role: 'owner' | 'admin';
  password: string;
};

const blankUser: NewUser = { name: '', email: '', role: 'admin', password: '' };

export default function AdminUsersPage() {
  const [users, setUsers] = useState<ManagedAdminUser[]>([]);
  const [newUser, setNewUser] = useState<NewUser>(blankUser);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState('');

  useEffect(() => {
    api<{ users: ManagedAdminUser[] }>('/admin/users')
      .then((data) => setUsers(data.users))
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
      setUsers((currentUsers) => [...currentUsers, data.user]);
      setNewUser(blankUser);
      setNotice(`Administrator ${data.user.email} created.`);
      setError('');
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : 'Unable to create administrator.');
    } finally {
      setWorking('');
    }
  };

  const saveUser = useCallback(async (id: number, draft: AdminUserDraft) => {
    setWorking(`save-${id}`);
    try {
      const data = await api<{ user: ManagedAdminUser }>(`/admin/users/${id}`, {
        method: 'PATCH',
        body: JSON.stringify(draft),
      });
      setUsers((currentUsers) => currentUsers.map((user) => user.id === id ? data.user : user));
      setNotice(`Administrator ${data.user.email} updated.`);
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Unable to update administrator.');
    } finally {
      setWorking('');
    }
  }, []);

  const resetPassword = useCallback(async (id: number, password: string) => {
    setWorking(`password-${id}`);
    try {
      const data = await api<{ message: string }>(`/admin/users/${id}/reset-password`, {
        method: 'POST',
        body: JSON.stringify({ password }),
      });
      setNotice(data.message);
      setError('');
      return true;
    } catch (resetError) {
      setError(resetError instanceof Error ? resetError.message : 'Unable to reset password.');
      return false;
    } finally {
      setWorking('');
    }
  }, []);

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
        {users.map((user) => (
          <AdminUserCard
            key={user.id}
            user={user}
            disabled={Boolean(working)}
            onSave={saveUser}
            onResetPassword={resetPassword}
          />
        ))}
      </div>
    </>
  );
}
