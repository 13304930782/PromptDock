import { useCallback, useEffect, useMemo, useState } from 'react';
import { Mail, RotateCw, Send, X } from 'lucide-react';
import { api } from '../lib/api';
import type { AdminUser, Application, EarlyAccessSettings } from '../types';

const roleLabels: Record<string, string> = {
  student: 'Student',
  creator: 'Creator',
  developer: 'Developer',
  researcher: 'Researcher',
  product: 'Product / Design',
  other: 'Other',
};

function formatDate(value: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function AdminApplicationsPage({ user }: { user: AdminUser }) {
  const [applications, setApplications] = useState<Application[]>([]);
  const [settings, setSettings] = useState<EarlyAccessSettings | null>(null);
  const [status, setStatus] = useState('pending');
  const [keyword, setKeyword] = useState('');
  const [selected, setSelected] = useState<Application | null>(null);
  const [internalNote, setInternalNote] = useState('');
  const [applicantMessage, setApplicantMessage] = useState('');
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');
  const [working, setWorking] = useState(false);
  const [bulkWorking, setBulkWorking] = useState(false);

  const load = useCallback(async () => {
    try {
      const query = new URLSearchParams({ status });
      if (keyword.trim()) query.set('keyword', keyword.trim());
      const [items, settingsData] = await Promise.all([
        api<{ applications: Application[] }>(`/admin/early-access?${query}`),
        api<{ settings: EarlyAccessSettings }>('/admin/settings/early-access'),
      ]);
      setApplications(items.applications);
      setSettings(settingsData.settings);
      setError('');
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : 'Unable to load applications.');
    }
  }, [keyword, status]);

  useEffect(() => {
    const timer = window.setTimeout(load, 180);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    if (selected) {
      setInternalNote(selected.internal_note || '');
      setApplicantMessage(selected.applicant_message || '');
    }
  }, [selected]);

  const counts = useMemo(() => ({
    shown: applications.length,
    pending: applications.filter((item) => item.status === 'pending').length,
  }), [applications]);

  const review = async (decision: 'approved' | 'rejected') => {
    if (!selected) return;
    if (decision === 'approved' && !settings?.download_url) {
      setError('Configure the PromptDock download URL before approving applications.');
      return;
    }
    const confirmed = window.confirm(
      `${decision === 'approved' ? 'Approve' : 'Reject'} ${selected.full_name}'s application? This decision cannot be changed.`,
    );
    if (!confirmed) return;
    setWorking(true);
    setError('');
    try {
      const result = await api<{ message: string; email_status: string }>(`/admin/early-access/${selected.id}/review`, {
        method: 'PATCH',
        body: JSON.stringify({
          decision,
          internal_note: internalNote,
          applicant_message: applicantMessage,
        }),
        timeoutMs: 130_000,
      });
      setNotice(`${result.message}${result.email_status === 'failed' ? ' The email failed and can be retried.' : ''}`);
      setSelected(null);
      await load();
    } catch (reviewError) {
      setError(reviewError instanceof Error ? reviewError.message : 'Unable to review application.');
    } finally {
      setWorking(false);
    }
  };

  const retryEmail = async () => {
    if (!selected) return;
    setWorking(true);
    try {
      const result = await api<{ message: string }>(`/admin/early-access/${selected.id}/retry-email`, {
        method: 'POST',
        timeoutMs: 130_000,
      });
      setNotice(result.message);
      setSelected(null);
      await load();
    } catch (retryError) {
      setError(retryError instanceof Error ? retryError.message : 'Unable to retry email.');
    } finally {
      setWorking(false);
    }
  };

  const resendApprovedEmails = async () => {
    const approved = applications.filter((item) => item.status === 'approved');
    if (user.role !== 'owner' || approved.length === 0) return;
    const confirmed = window.confirm(
      'Resend the approval email to every approved Early Access user? Their previous feedback links will be replaced.',
    );
    if (!confirmed) return;

    setBulkWorking(true);
    setError('');
    try {
      const result = await api<{ message: string; sent: number; failed: number }>('/admin/early-access/resend-approved', {
        method: 'POST',
        body: JSON.stringify({ confirm: true }),
        timeoutMs: 180_000,
      });
      setNotice(result.message);
      await load();
    } catch (resendError) {
      setError(resendError instanceof Error ? resendError.message : 'Unable to resend approval emails.');
    } finally {
      setBulkWorking(false);
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>Early Access</h1><p>Review PromptDock applicants and monitor decision emails.</p></div>
        <span className="status-badge pending">{counts.shown} shown</span>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}
      {!settings?.download_url && (
        <div className="admin-alert error">Approvals are disabled until a download URL is saved in Settings.</div>
      )}
      <div className="admin-filters">
        <input type="search" placeholder="Search name, email, role, or answers…" value={keyword} onChange={(event) => setKeyword(event.target.value)} />
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="all">All statuses</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>
        {user.role === 'owner' && applications.some((item) => item.status === 'approved') && (
          <button className="button button-retry" type="button" disabled={bulkWorking} onClick={resendApprovedEmails}>
            <Send size={17} />{bulkWorking ? 'Sending…' : 'Resend to all approved'}
          </button>
        )}
      </div>
      {user.role === 'owner' && applications.some((item) => item.status === 'approved') && (
        <p className="admin-help-text">Sends to every approved user and replaces each user’s previous private feedback link.</p>
      )}
      <div className="admin-card">
        {applications.length === 0 ? (
          <div className="empty-admin">No applications match these filters.</div>
        ) : (
          <table className="applications-table">
            <thead><tr><th>Applicant</th><th>Role</th><th>Locale</th><th>Status</th><th>Email</th><th>Submitted</th></tr></thead>
            <tbody>
              {applications.map((item) => (
                <tr key={item.id} onClick={() => setSelected(item)}>
                  <td><div className="application-person"><strong>{item.full_name}</strong><span>{item.email}</span></div></td>
                  <td>{roleLabels[item.role] || item.role}</td>
                  <td>{item.locale === 'zh' ? '中文' : 'English'}</td>
                  <td><span className={`status-badge ${item.status}`}>{item.status}</span></td>
                  <td><span className={`status-badge ${item.latest_email_status || 'not_sent'}`}>{item.latest_email_status || 'not sent'}</span></td>
                  <td>{formatDate(item.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {selected && (
        <>
          <div className="drawer-backdrop" onClick={() => setSelected(null)} />
          <aside className="application-drawer" aria-label="Application details">
            <div className="drawer-header">
              <div><h2>{selected.full_name}</h2><p>{selected.email}</p></div>
              <button className="icon-button" type="button" onClick={() => setSelected(null)} aria-label="Close"><X size={19} /></button>
            </div>
            <div className="detail-grid">
              <div className="detail-item"><span>Status</span><strong>{selected.status}</strong></div>
              <div className="detail-item"><span>Role</span><strong>{roleLabels[selected.role] || selected.role}</strong></div>
              <div className="detail-item"><span>Language</span><strong>{selected.locale === 'zh' ? '中文' : 'English'}</strong></div>
              <div className="detail-item"><span>Cohort</span><strong>{selected.cohort}</strong></div>
              <div className="detail-item"><span>Submitted</span><strong>{formatDate(selected.created_at)}</strong></div>
              <div className="detail-item"><span>Decision email</span><strong>{selected.latest_email_status || 'Not sent'}</strong></div>
            </div>
            <div className="detail-block"><span>Use case</span><p>{selected.use_case}</p></div>
            <div className="detail-block"><span>Motivation</span><p>{selected.motivation}</p></div>
            {selected.latest_email_error && <div className="admin-alert error">{selected.latest_email_error}</div>}
            {selected.status === 'pending' ? (
              <div className="review-form">
                <label>Internal note<textarea value={internalNote} maxLength={2000} onChange={(event) => setInternalNote(event.target.value)} placeholder="Visible only to administrators." /></label>
                <label>Optional applicant message<textarea value={applicantMessage} maxLength={1500} onChange={(event) => setApplicantMessage(event.target.value)} placeholder="Included in the decision email." /></label>
                <div className="review-actions">
                  <button className="button button-approve" type="button" disabled={working || !settings?.download_url} onClick={() => review('approved')}>Approve</button>
                  <button className="button button-reject" type="button" disabled={working} onClick={() => review('rejected')}>Reject</button>
                </div>
              </div>
            ) : (
              <>
                <div className="detail-block"><span>Reviewed by</span><p>{selected.reviewer_name || '—'} · {formatDate(selected.reviewed_at)}</p></div>
                {selected.internal_note && <div className="detail-block"><span>Internal note</span><p>{selected.internal_note}</p></div>}
                {selected.applicant_message && <div className="detail-block"><span>Applicant message</span><p>{selected.applicant_message}</p></div>}
                {selected.latest_email_status !== 'sent' && (
                  <button className="button button-retry" type="button" disabled={working} onClick={retryEmail}>
                    <RotateCw size={17} />{selected.latest_email_status === 'failed' ? 'Retry decision email' : 'Send decision email'}
                  </button>
                )}
                {selected.latest_email_status === 'sent' && <div className="button button-retry"><Mail size={17} />Decision email sent</div>}
              </>
            )}
          </aside>
        </>
      )}
    </>
  );
}
