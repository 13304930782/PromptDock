import { useEffect, useState } from 'react';
import { Copy, KeyRound, Plus, ShieldX, Trash2 } from 'lucide-react';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { RollAccessKeyRecord } from '../types';

function keyStatus(record: RollAccessKeyRecord): 'revoked' | 'expired' | 'active' {
  if (record.revoked_at) return 'revoked';
  if (new Date(record.expires_at).getTime() <= Date.now()) return 'expired';
  return 'active';
}

export default function AdminRollAccessPage() {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const [keys, setKeys] = useState<RollAccessKeyRecord[]>([]);
  const [generatedKey, setGeneratedKey] = useState('');
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState(false);
  const [selectedIds, setSelectedIds] = useState<number[]>([]);

  useEffect(() => {
    api<{ access_keys: RollAccessKeyRecord[] }>('/admin/roll-access-keys')
      .then((data) => setKeys(data.access_keys))
      .catch((loadError) => setError(loadError instanceof Error ? loadError.message : (zh ? '无法加载访问密钥。' : 'Unable to load access keys.')));
  }, [zh]);

  const generateKey = async () => {
    setWorking(true);
    try {
      const data = await api<{ access_key: string; record: RollAccessKeyRecord }>('/admin/roll-access-keys', { method: 'POST' });
      setGeneratedKey(data.access_key);
      setKeys((current) => [data.record, ...current]);
      setNotice(zh ? '新的 24 小时访问密钥已生成。请立即复制，之后将无法再次显示。' : 'A new 24-hour access key was created. Copy it now; it cannot be displayed again.');
      setError('');
    } catch (generateError) {
      setError(generateError instanceof Error ? generateError.message : (zh ? '无法生成访问密钥。' : 'Unable to create an access key.'));
    } finally {
      setWorking(false);
    }
  };

  const copyKey = async () => {
    try {
      await navigator.clipboard.writeText(generatedKey);
      setNotice(zh ? '访问密钥已复制。' : 'Access key copied.');
      setError('');
    } catch {
      setError(zh ? '无法自动复制，请手动选中并复制密钥。' : 'Unable to copy automatically. Select and copy the key manually.');
    }
  };

  const revokeKey = async (id: number) => {
    setWorking(true);
    try {
      await api(`/admin/roll-access-keys/${id}/revoke`, { method: 'POST' });
      setKeys((current) => current.map((item) => item.id === id ? { ...item, revoked_at: new Date().toISOString() } : item));
      setNotice(zh ? '访问密钥已撤销，现有会话将在下次权限检查时失效。' : 'Access key revoked. Existing sessions will be rejected on their next access check.');
      setError('');
    } catch (revokeError) {
      setError(revokeError instanceof Error ? revokeError.message : (zh ? '无法撤销访问密钥。' : 'Unable to revoke the access key.'));
    } finally {
      setWorking(false);
    }
  };

  const deleteKey = async (record: RollAccessKeyRecord) => {
    const active = keyStatus(record) === 'active';
    const confirmed = window.confirm(zh
      ? `确定永久删除密钥 ${record.key_prefix}…吗？${active ? '该密钥的现有访问将在下一次权限检查时失效。' : ''}`
      : `Permanently delete ${record.key_prefix}…?${active ? ' Existing access using this key will end at the next access check.' : ''}`);
    if (!confirmed) return;
    setWorking(true);
    try {
      await api(`/admin/roll-access-keys/${record.id}`, { method: 'DELETE' });
      setKeys((current) => current.filter((item) => item.id !== record.id));
      setSelectedIds((current) => current.filter((id) => id !== record.id));
      setGeneratedKey('');
      setNotice(zh ? '访问密钥已永久删除。' : 'Access key permanently deleted.');
      setError('');
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : (zh ? '无法删除访问密钥。' : 'Unable to delete the access key.'));
    } finally {
      setWorking(false);
    }
  };

  const deleteSelected = async () => {
    const selected = keys.filter((record) => selectedIds.includes(record.id));
    if (!selected.length) return;
    const activeCount = selected.filter((record) => keyStatus(record) === 'active').length;
    const confirmed = window.confirm(zh
      ? `确定永久删除选中的 ${selected.length} 个密钥吗？${activeCount ? `其中 ${activeCount} 个仍然有效，对应访问将在下一次权限检查时失效。` : ''}`
      : `Permanently delete ${selected.length} selected key${selected.length === 1 ? '' : 's'}?${activeCount ? ` Access using ${activeCount} active key${activeCount === 1 ? '' : 's'} will end at the next access check.` : ''}`);
    if (!confirmed) return;
    setWorking(true);
    try {
      const data = await api<{ deleted: number }>('/admin/roll-access-keys', {
        method: 'DELETE',
        body: JSON.stringify({ ids: selected.map((record) => record.id) }),
      });
      const deletedIds = new Set(selected.map((record) => record.id));
      setKeys((current) => current.filter((record) => !deletedIds.has(record.id)));
      setSelectedIds([]);
      setGeneratedKey('');
      setNotice(zh ? `已永久删除 ${data.deleted} 个访问密钥。` : `${data.deleted} access key${data.deleted === 1 ? '' : 's'} permanently deleted.`);
      setError('');
    } catch (deleteError) {
      setError(deleteError instanceof Error ? deleteError.message : (zh ? '无法删除所选访问密钥。' : 'Unable to delete the selected access keys.'));
    } finally {
      setWorking(false);
    }
  };

  const allSelected = keys.length > 0 && keys.every((record) => selectedIds.includes(record.id));

  return (
    <>
      <div className="admin-topline">
        <div><h1>{zh ? '工具访问密钥' : 'Tool access keys'}</h1><p>{zh ? '为受保护的随机工具签发临时密钥，每个密钥生成 24 小时后过期。' : 'Issue temporary keys for the protected random tools. Every key expires 24 hours after creation.'}</p></div>
        <button className="button button-approve" type="button" disabled={working} onClick={generateKey}><Plus size={16} />{zh ? '生成密钥' : 'Generate key'}</button>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      {generatedKey && (
        <section className="admin-card generated-key-card" aria-live="polite">
          <div><KeyRound size={22} /><span>{zh ? '新访问密钥' : 'New access key'}</span><strong>{generatedKey}</strong></div>
          <button className="button button-secondary" type="button" onClick={copyKey}><Copy size={15} />{zh ? '复制' : 'Copy'}</button>
        </section>
      )}

      <div className="roll-key-toolbar">
        <span>{selectedIds.length ? (zh ? `已选择 ${selectedIds.length} 个` : `${selectedIds.length} selected`) : (zh ? '选择密钥后可批量删除' : 'Select keys to delete in bulk')}</span>
        <button className="button button-reject" type="button" disabled={working || selectedIds.length === 0} onClick={deleteSelected}><Trash2 size={15} />{zh ? '删除所选' : 'Delete selected'}</button>
      </div>

      <section className="admin-card roll-key-list">
        <div className="roll-key-list-head">
          <input type="checkbox" checked={allSelected} disabled={!keys.length || working} aria-label={zh ? '选择全部密钥' : 'Select all access keys'} onChange={(event) => setSelectedIds(event.target.checked ? keys.map((record) => record.id) : [])} />
          <span>{zh ? '密钥' : 'Key'}</span><span>{zh ? '创建者' : 'Created by'}</span><span>{zh ? '过期时间' : 'Expires'}</span><span>{zh ? '使用次数' : 'Usage'}</span><span>{zh ? '状态' : 'Status'}</span><span>{zh ? '操作' : 'Actions'}</span>
        </div>
        {keys.length === 0 ? <div className="empty-admin">{zh ? '尚未生成访问密钥。' : 'No access keys have been created.'}</div> : keys.map((record) => {
          const status = keyStatus(record);
          return (
            <div className="roll-key-row" key={record.id}>
              <input type="checkbox" checked={selectedIds.includes(record.id)} disabled={working} aria-label={zh ? `选择密钥 ${record.key_prefix}` : `Select key ${record.key_prefix}`} onChange={(event) => setSelectedIds((current) => event.target.checked ? [...current, record.id] : current.filter((id) => id !== record.id))} />
              <strong>{record.key_prefix}…</strong>
              <span>{record.created_by_name || (zh ? '已删除的管理员' : 'Deleted administrator')}</span>
              <span>{new Date(record.expires_at).toLocaleString(zh ? 'zh-CN' : 'en-US')}</span>
              <span>{record.use_count}</span>
              <span className={`status-badge ${status === 'active' ? 'approved' : 'rejected'}`}>{zh ? ({ active: '有效', expired: '已过期', revoked: '已撤销' }[status]) : status}</span>
              <div className="roll-key-row-actions">
                <button type="button" className="text-button" disabled={working || status !== 'active'} onClick={() => revokeKey(record.id)}><ShieldX size={14} />{zh ? '撤销' : 'Revoke'}</button>
                <button type="button" className="text-button danger" disabled={working} onClick={() => deleteKey(record)}><Trash2 size={14} />{zh ? '删除' : 'Delete'}</button>
              </div>
            </div>
          );
        })}
      </section>
    </>
  );
}
