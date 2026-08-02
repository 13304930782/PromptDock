import { FormEvent, useCallback, useEffect, useState } from 'react';
import { Send, X } from 'lucide-react';
import { api } from '../lib/api';
import type { FeedbackReport } from '../types';

const statuses = ['new', 'triaged', 'resolved', 'all'] as const;

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function AdminFeedbackPage() {
  const [status, setStatus] = useState<(typeof statuses)[number]>('new');
  const [keyword, setKeyword] = useState('');
  const [reports, setReports] = useState<FeedbackReport[]>([]);
  const [selected, setSelected] = useState<FeedbackReport | null>(null);
  const [reply, setReply] = useState('');
  const [message, setMessage] = useState('');
  const [notice, setNotice] = useState('');
  const [working, setWorking] = useState(false);

  const load = useCallback(async () => {
    try {
      const params = new URLSearchParams({ status });
      if (keyword.trim()) params.set('keyword', keyword.trim());
      const result = await api<{ reports: FeedbackReport[] }>(`/admin/feedback?${params}`);
      setReports(result.reports);
      setMessage('');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to load feedback.');
    }
  }, [keyword, status]);

  const openReport = useCallback(async (id: number) => {
    try {
      const result = await api<{ report: FeedbackReport }>(`/admin/feedback/${id}`);
      setSelected(result.report);
      setMessage('');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to load feedback details.');
    }
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(load, 180);
    return () => window.clearTimeout(timer);
  }, [load]);

  useEffect(() => {
    const reportId = Number(new URLSearchParams(window.location.search).get('report'));
    if (Number.isInteger(reportId) && reportId > 0) openReport(reportId);
  }, [openReport]);

  useEffect(() => {
    if (!selected) return undefined;
    const timer = window.setInterval(() => openReport(selected.id), 10_000);
    return () => window.clearInterval(timer);
  }, [openReport, selected?.id]);

  const updateStatus = async (id: number, nextStatus: 'new' | 'triaged' | 'resolved') => {
    const current = reports.find((report) => report.id === id);
    if (current?.status === nextStatus) return;
    if (nextStatus === 'resolved' && !window.confirm(`Mark “${current?.title || 'this report'}” as resolved?`)) {
      return;
    }
    await api(`/admin/feedback/${id}`, { method: 'PATCH', body: JSON.stringify({ status: nextStatus }) });
    await load();
    if (selected?.id === id) await openReport(id);
  };

  const sendReply = async (event: FormEvent) => {
    event.preventDefault();
    if (!selected || !reply.trim()) return;
    setWorking(true);
    setMessage('');
    try {
      const result = await api<{ message: string; email_status: string }>(`/admin/feedback/${selected.id}/replies`, {
        method: 'POST',
        body: JSON.stringify({ body: reply }),
        timeoutMs: 130_000,
      });
      setReply('');
      setNotice(result.email_status === 'sent' ? 'Reply sent and the tester was notified by email.' : 'Reply saved, but the notification email was not delivered.');
      await load();
      await openReport(selected.id);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to send reply.');
    } finally {
      setWorking(false);
    }
  };

  return (
    <>
      <header className="admin-topline">
        <div><p className="eyebrow">PromptDock</p><h1>Tester feedback</h1><p>Open a report to review its history and reply to the tester.</p></div>
        <div className="admin-filters"><input aria-label="Search feedback" value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Name, email, title" /><select aria-label="Feedback status" value={status} onChange={(event) => setStatus(event.target.value as (typeof statuses)[number])}>{statuses.map((value) => <option key={value} value={value}>{value}</option>)}</select></div>
      </header>
      {notice && <div className="admin-alert">{notice}</div>}
      {message && <div className="admin-alert error" role="alert">{message}</div>}
      <section className="admin-card">
        {reports.length === 0 ? <div className="empty-admin">No feedback in this view.</div> : (
          <div className="admin-table-wrap"><table className="applications-table"><thead><tr><th>Report</th><th>Tester</th><th>Build</th><th>Status</th><th>Replies</th></tr></thead><tbody>
            {reports.map((report) => <tr key={report.id} onClick={() => openReport(report.id)}><td><strong>{report.title}</strong><small>{report.category} · {formatDate(report.created_at)}</small><p>{report.details}</p></td><td>{report.full_name}<small>{report.email}</small></td><td>{report.app_build || '—'}<small>{report.device || '—'} {report.macos_version || ''}</small></td><td><select value={report.status} onClick={(event) => event.stopPropagation()} onChange={(event) => updateStatus(report.id, event.target.value as 'new' | 'triaged' | 'resolved')} aria-label={`Status for ${report.title}`}><option value="new">new</option><option value="triaged">triaged</option><option value="resolved">resolved</option></select></td><td>{report.message_count || 0}</td></tr>)}
          </tbody></table></div>
        )}
      </section>

      {selected && (
        <>
          <div className="drawer-backdrop" onClick={() => setSelected(null)} />
          <aside className="application-drawer feedback-drawer" aria-label="Feedback conversation">
            <div className="drawer-header">
              <div><p className="eyebrow">{selected.category} · {selected.status}</p><h2>{selected.title}</h2><p>{selected.full_name} · {selected.email}</p></div>
              <button className="icon-button" type="button" onClick={() => setSelected(null)} aria-label="Close"><X size={19} /></button>
            </div>
            <div className="feedback-report-body">
              <p>{selected.details}</p>
              {selected.steps && <div className="detail-block"><span>Steps to reproduce</span><p>{selected.steps}</p></div>}
              {selected.expected && <div className="detail-block"><span>Expected</span><p>{selected.expected}</p></div>}
              {selected.actual && <div className="detail-block"><span>Actual</span><p>{selected.actual}</p></div>}
              <small>{formatDate(selected.created_at)} · {selected.device || 'Unknown Mac'} · macOS {selected.macos_version || '—'} · Build {selected.app_build || '—'}</small>
            </div>
            <div className="feedback-thread" aria-live="polite">
              {(selected.messages || []).map((item) => (
                <article className={`feedback-message ${item.author_type}`} key={item.id}>
                  <strong>{item.author_type === 'developer' ? (item.admin_name || 'PromptDock developer') : selected.full_name}</strong>
                  <p>{item.body}</p>
                  <time>{formatDate(item.created_at)}</time>
                </article>
              ))}
              {(selected.messages || []).length === 0 && <p className="empty-thread">No replies yet.</p>}
            </div>
            <form className="feedback-reply-form" onSubmit={sendReply}>
              <label>Developer reply<textarea required maxLength={4000} value={reply} onChange={(event) => setReply(event.target.value)} placeholder="Share progress, ask a question, or confirm the fix…" /></label>
              <button className="button button-primary" type="submit" disabled={working || !reply.trim()}><Send size={16} />{working ? 'Sending…' : 'Reply and notify tester'}</button>
            </form>
          </aside>
        </>
      )}
    </>
  );
}
