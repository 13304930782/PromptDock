import { FormEvent, useCallback, useEffect, useState } from 'react';
import { Send, X } from 'lucide-react';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { FeedbackReport } from '../types';

const statuses = ['new', 'triaged', 'resolved', 'all'] as const;

function formatDate(value: string, locale: 'zh' | 'en') {
  return new Intl.DateTimeFormat(locale === 'zh' ? 'zh-CN' : 'en-US', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function AdminFeedbackPage() {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const statusLabel = (value: string) => zh ? ({ new: '新反馈', triaged: '处理中', resolved: '已解决', all: '全部' }[value] || value) : value;
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
      setMessage(error instanceof Error ? error.message : (zh ? '无法加载反馈。' : 'Unable to load feedback.'));
    }
  }, [keyword, status, zh]);

  const openReport = useCallback(async (id: number) => {
    try {
      const result = await api<{ report: FeedbackReport }>(`/admin/feedback/${id}`);
      setSelected(result.report);
      setMessage('');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法加载反馈详情。' : 'Unable to load feedback details.'));
    }
  }, [zh]);

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
    await api(`/admin/feedback/${id}`, { method: 'PATCH', body: JSON.stringify({ status: nextStatus }) });
    await Promise.all([load(), selected?.id === id ? openReport(id) : Promise.resolve()]);
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
      setNotice(result.email_status === 'sent' ? (zh ? '回复已发送，并已通过邮件通知测试用户。' : 'Reply sent and the tester was notified by email.') : (zh ? '回复已保存，但通知邮件未送达。' : 'Reply saved, but the notification email was not delivered.'));
      await Promise.all([load(), openReport(selected.id)]);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : (zh ? '无法发送回复。' : 'Unable to send reply.'));
    } finally {
      setWorking(false);
    }
  };

  return (
    <>
      <header className="admin-topline">
        <div><p className="eyebrow">PromptDock</p><h1>{zh ? '测试用户反馈' : 'Tester feedback'}</h1><p>{zh ? '打开反馈记录，查看沟通历史并回复测试用户。' : 'Open a report to review its history and reply to the tester.'}</p></div>
        <div className="admin-filters"><input aria-label={zh ? '搜索反馈' : 'Search feedback'} value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder={zh ? '姓名、邮箱、标题' : 'Name, email, title'} /><select aria-label={zh ? '反馈状态' : 'Feedback status'} value={status} onChange={(event) => setStatus(event.target.value as (typeof statuses)[number])}>{statuses.map((value) => <option key={value} value={value}>{statusLabel(value)}</option>)}</select></div>
      </header>
      {notice && <div className="admin-alert">{notice}</div>}
      {message && <div className="admin-alert error" role="alert">{message}</div>}
      <section className="admin-card">
        {reports.length === 0 ? <div className="empty-admin">{zh ? '当前视图中没有反馈。' : 'No feedback in this view.'}</div> : (
          <div className="admin-table-wrap"><table className="applications-table"><thead><tr><th>{zh ? '反馈' : 'Report'}</th><th>{zh ? '测试用户' : 'Tester'}</th><th>{zh ? '版本' : 'Build'}</th><th>{zh ? '状态' : 'Status'}</th><th>{zh ? '回复数' : 'Replies'}</th></tr></thead><tbody>
            {reports.map((report) => <tr key={report.id} onClick={() => openReport(report.id)}><td><strong>{report.title}</strong><small>{report.category} · {formatDate(report.created_at, locale)}</small><p>{report.details}</p></td><td>{report.full_name}<small>{report.email}</small></td><td>{report.app_build || '—'}<small>{report.device || '—'} {report.macos_version || ''}</small></td><td><select value={report.status} onClick={(event) => event.stopPropagation()} onChange={(event) => updateStatus(report.id, event.target.value as 'new' | 'triaged' | 'resolved')} aria-label={`${zh ? '状态' : 'Status for'} ${report.title}`}><option value="new">{statusLabel('new')}</option><option value="triaged">{statusLabel('triaged')}</option><option value="resolved">{statusLabel('resolved')}</option></select></td><td>{report.message_count || 0}</td></tr>)}
          </tbody></table></div>
        )}
      </section>

      {selected && (
        <>
          <div className="drawer-backdrop" onClick={() => setSelected(null)} />
          <aside className="application-drawer feedback-drawer" aria-label={zh ? '反馈对话' : 'Feedback conversation'}>
            <div className="drawer-header">
              <div><p className="eyebrow">{selected.category} · {selected.status}</p><h2>{selected.title}</h2><p>{selected.full_name} · {selected.email}</p></div>
              <button className="icon-button" type="button" onClick={() => setSelected(null)} aria-label={zh ? '关闭' : 'Close'}><X size={19} /></button>
            </div>
            <div className="feedback-report-body">
              <p>{selected.details}</p>
              {selected.steps && <div className="detail-block"><span>{zh ? '复现步骤' : 'Steps to reproduce'}</span><p>{selected.steps}</p></div>}
              {selected.expected && <div className="detail-block"><span>{zh ? '预期结果' : 'Expected'}</span><p>{selected.expected}</p></div>}
              {selected.actual && <div className="detail-block"><span>{zh ? '实际结果' : 'Actual'}</span><p>{selected.actual}</p></div>}
              <small>{formatDate(selected.created_at, locale)} · {selected.device || (zh ? '未知 Mac' : 'Unknown Mac')} · macOS {selected.macos_version || '—'} · {zh ? '版本' : 'Build'} {selected.app_build || '—'}</small>
            </div>
            <div className="feedback-thread" aria-live="polite">
              {(selected.messages || []).map((item) => (
                <article className={`feedback-message ${item.author_type}`} key={item.id}>
                  <strong>{item.author_type === 'developer' ? (item.admin_name || (zh ? 'PromptDock 开发者' : 'PromptDock developer')) : selected.full_name}</strong>
                  <p>{item.body}</p>
                  <time>{formatDate(item.created_at, locale)}</time>
                </article>
              ))}
              {(selected.messages || []).length === 0 && <p className="empty-thread">{zh ? '暂无回复。' : 'No replies yet.'}</p>}
            </div>
            <form className="feedback-reply-form" onSubmit={sendReply}>
              <label>{zh ? '开发者回复' : 'Developer reply'}<textarea required maxLength={4000} value={reply} onChange={(event) => setReply(event.target.value)} placeholder={zh ? '同步进展、提出问题或确认修复情况…' : 'Share progress, ask a question, or confirm the fix…'} /></label>
              <button className="button button-primary" type="submit" disabled={working || !reply.trim()}><Send size={16} />{working ? (zh ? '正在发送…' : 'Sending…') : (zh ? '回复并通知测试用户' : 'Reply and notify tester')}</button>
            </form>
          </aside>
        </>
      )}
    </>
  );
}
