import { useEffect, useState } from 'react';
import { Copy, KeyRound, Plus, ShieldX } from 'lucide-react';
import { api } from '../lib/api';
import type { RollAccessKeyRecord } from '../types';

function keyStatus(record: RollAccessKeyRecord) {
  if (record.revoked_at) return 'revoked';
  if (new Date(record.expires_at).getTime() <= Date.now()) return 'expired';
  return 'active';
}

export default function AdminRollAccessPage() {
  const [keys, setKeys] = useState<RollAccessKeyRecord[]>([]);
  const [generatedKey, setGeneratedKey] = useState('');
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState(false);

  useEffect(() => {
    api<{ access_keys: RollAccessKeyRecord[] }>('/admin/roll-access-keys')
      .then((data) => setKeys(data.access_keys))
      .catch((loadError) => setError(loadError instanceof Error ? loadError.message : 'Unable to load access keys.'));
  }, []);

  const generateKey = async () => {
    setWorking(true);
    try {
      const data = await api<{ access_key: string; record: RollAccessKeyRecord }>('/admin/roll-access-keys', { method: 'POST' });
      setGeneratedKey(data.access_key);
      setKeys((current) => [data.record, ...current]);
      setNotice('A new 24-hour access key was created. Copy it now; it cannot be displayed again.');
      setError('');
    } catch (generateError) {
      setError(generateError instanceof Error ? generateError.message : 'Unable to create an access key.');
    } finally {
      setWorking(false);
    }
  };

  const copyKey = async () => {
    try {
      await navigator.clipboard.writeText(generatedKey);
      setNotice('Access key copied.');
      setError('');
    } catch {
      setError('Unable to copy automatically. Select and copy the key manually.');
    }
  };

  const revokeKey = async (id: number) => {
    setWorking(true);
    try {
      await api(`/admin/roll-access-keys/${id}/revoke`, { method: 'POST' });
      setKeys((current) => current.map((item) => item.id === id ? { ...item, revoked_at: new Date().toISOString() } : item));
      setNotice('Access key revoked. Existing sessions will be rejected on their next access check.');
      setError('');
    } catch (revokeError) {
      setError(revokeError instanceof Error ? revokeError.message : 'Unable to revoke the access key.');
    } finally {
      setWorking(false);
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>Tool access keys</h1><p>Issue temporary keys for the protected random tools. Every key expires 24 hours after creation.</p></div>
        <button className="button button-approve" type="button" disabled={working} onClick={generateKey}><Plus size={16} />Generate key</button>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}

      {generatedKey && (
        <section className="admin-card generated-key-card" aria-live="polite">
          <div><KeyRound size={22} /><span>New access key</span><strong>{generatedKey}</strong></div>
          <button className="button button-secondary" type="button" onClick={copyKey}><Copy size={15} />Copy</button>
        </section>
      )}

      <section className="admin-card roll-key-list">
        <div className="roll-key-list-head"><span>Key</span><span>Created by</span><span>Expires</span><span>Usage</span><span>Status</span><span /></div>
        {keys.length === 0 ? <div className="empty-admin">No access keys have been created.</div> : keys.map((record) => {
          const status = keyStatus(record);
          return (
            <div className="roll-key-row" key={record.id}>
              <strong>{record.key_prefix}…</strong>
              <span>{record.created_by_name || 'Deleted administrator'}</span>
              <span>{new Date(record.expires_at).toLocaleString()}</span>
              <span>{record.use_count}</span>
              <span className={`status-badge ${status === 'active' ? 'approved' : 'rejected'}`}>{status}</span>
              <button type="button" className="text-button" disabled={working || status !== 'active'} onClick={() => revokeKey(record.id)}><ShieldX size={14} />Revoke</button>
            </div>
          );
        })}
      </section>
    </>
  );
}
