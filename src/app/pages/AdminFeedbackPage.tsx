import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import type { FeedbackReport } from '../types';

const statuses = ['new', 'triaged', 'resolved', 'all'] as const;

export default function AdminFeedbackPage() {
  const [status, setStatus] = useState<(typeof statuses)[number]>('new');
  const [keyword, setKeyword] = useState('');
  const [reports, setReports] = useState<FeedbackReport[]>([]);
  const [message, setMessage] = useState('');

  const load = async () => {
    try {
      const params = new URLSearchParams({ status });
      if (keyword.trim()) params.set('keyword', keyword.trim());
      const result = await api<{ reports: FeedbackReport[] }>(`/admin/feedback?${params}`);
      setReports(result.reports);
      setMessage('');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to load feedback.');
    }
  };

  useEffect(() => { load(); }, [status, keyword]);

  const updateStatus = async (id: number, nextStatus: 'new' | 'triaged' | 'resolved') => {
    await api(`/admin/feedback/${id}`, { method: 'PATCH', body: JSON.stringify({ status: nextStatus }) });
    await load();
  };

  return (
    <main className="admin-page">
      <header className="admin-topline">
        <div><p className="eyebrow">PromptDock</p><h1>Tester feedback</h1><p>Review structured reports without asking users to share private prompts.</p></div>
        <div className="admin-filters"><input aria-label="Search feedback" value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Name, email, title" /><select aria-label="Feedback status" value={status} onChange={(event) => setStatus(event.target.value as (typeof statuses)[number])}>{statuses.map((value) => <option key={value} value={value}>{value}</option>)}</select></div>
      </header>
      {message && <p className="form-error" role="alert">{message}</p>}
      <section className="admin-card">
        {reports.length === 0 ? <p>No feedback in this view.</p> : (
          <div className="admin-table-wrap"><table className="applications-table"><thead><tr><th>Report</th><th>Tester</th><th>Build</th><th>Status</th><th>Actions</th></tr></thead><tbody>
            {reports.map((report) => <tr key={report.id}><td><strong>{report.title}</strong><small>{report.category} · {new Date(report.created_at).toLocaleString()}</small><p>{report.details}</p></td><td>{report.full_name}<small>{report.email}</small></td><td>{report.app_build || '—'}<small>{report.device || '—'} {report.macos_version || ''}</small></td><td>{report.status}</td><td><select value={report.status} onChange={(event) => updateStatus(report.id, event.target.value as 'new' | 'triaged' | 'resolved')} aria-label={`Status for ${report.title}`}><option value="new">new</option><option value="triaged">triaged</option><option value="resolved">resolved</option></select></td></tr>)}
          </tbody></table></div>
        )}
      </section>
    </main>
  );
}
