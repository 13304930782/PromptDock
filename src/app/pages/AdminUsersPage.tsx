import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import { Plus, ShieldCheck } from 'lucide-react';
import AdminUserCard, { type AdminUserDraft } from '../components/AdminUserCard';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { ManagedAdminUser } from '../types';

type NewUser = {
  name: string;
  email: string;
  role: 'owner' | 'admin';
  password: string;
};

const blankUser: NewUser = { name: '', email: '', role: 'admin', password: '' };

export default function AdminUsersPage() {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [users, setUsers] = useState<ManagedAdminUser[]>([]);
  const [newUser, setNewUser] = useState<NewUser>(blankUser);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState('');

  useEffect(() => {
    api<{ users: ManagedAdminUser[] }>('/admin/users')
      .then((data) => setUsers(data.users))
      .catch((loadError) => setError(loadError instanceof Error ? loadError.message : (zh ? '无法加载管理员。' : 'Unable to load administrators.')));
  }, [zh]);

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
      setNotice(zh ? `管理员 ${data.user.email} 已创建。` : `Administrator ${data.user.email} created.`);
      setError('');
    } catch (createError) {
      setError(createError instanceof Error ? createError.message : (zh ? '无法创建管理员。' : 'Unable to create administrator.'));
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
      setUsers((currentUsers) => currentUsers.map((user) => {
        if (user.id === id) return data.user;
        return data.user.can_issue_roll_keys ? { ...user, can_issue_roll_keys: false } : user;
      }));
      setNotice(zh ? `管理员 ${data.user.email} 已更新。` : `Administrator ${data.user.email} updated.`);
      setError('');
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : (zh ? '无法更新管理员。' : 'Unable to update administrator.'));
    } finally {
      setWorking('');
    }
  }, [zh]);

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
      setError(resetError instanceof Error ? resetError.message : (zh ? '无法重置密码。' : 'Unable to reset password.'));
      return false;
    } finally {
      setWorking('');
    }
  }, [zh]);

  return (
    <>
      <div className="admin-topline">
        <div><h1>{zh ? '管理员' : 'Administrators'}</h1><p>{zh ? '创建账号、管理角色，并指定一名管理员签发工具访问密钥。' : 'Create accounts, manage roles, and designate one administrator to issue tool access keys.'}</p></div>
        <span className="owner-count"><ShieldCheck size={16} />{zh ? `${activeOwners} 名有效站长` : `${activeOwners} active owner${activeOwners === 1 ? '' : 's'}`}</span>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      <section className="admin-card settings-card admin-create-card">
        <h2>{zh ? '添加管理员' : 'Add administrator'}</h2>
        <form className="admin-create-form" onSubmit={createUser}>
          <label>{zh ? '姓名' : 'Name'}<input value={newUser.name} onChange={(event) => setNewUser({ ...newUser, name: event.target.value })} required minLength={2} /></label>
          <label>{zh ? '邮箱' : 'Email'}<input type="email" value={newUser.email} onChange={(event) => setNewUser({ ...newUser, email: event.target.value })} required /></label>
          <label>{zh ? '角色' : 'Role'}
            <select value={newUser.role} onChange={(event) => setNewUser({ ...newUser, role: event.target.value as 'owner' | 'admin' })}>
              <option value="admin">{zh ? '管理员' : 'Admin'}</option>
              <option value="owner">{zh ? '站长' : 'Owner'}</option>
            </select>
          </label>
          <label>{zh ? '临时密码' : 'Temporary password'}<input type="password" value={newUser.password} onChange={(event) => setNewUser({ ...newUser, password: event.target.value })} minLength={8} autoComplete="new-password" autoCapitalize="none" spellCheck={false} required /></label>
          <button className="button button-approve" type="submit" disabled={Boolean(working)}><Plus size={16} />{zh ? '创建' : 'Create'}</button>
        </form>
        <p className="settings-hint">{zh ? '密码至少需要 8 个字符，并包含字母和数字。用户之后可以通过“忘记密码”进行修改。' : 'Passwords need at least 8 characters with letters and numbers. The user can change it later through “Forgot password”.'}</p>
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
