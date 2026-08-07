import { useCallback, useEffect, useMemo, useState } from 'react';
import { Mail, RotateCw, Send, X } from 'lucide-react';
import { api } from '../lib/api';
import { useAdminLocale } from '../lib/adminLocale';
import type { AdminUser, Application, EarlyAccessSettings } from '../types';

const roleLabels = {
  zh: { student: '学生', creator: '创作者', developer: '开发者', researcher: '研究者', product: '产品 / 设计', other: '其他' },
  en: { student: 'Student', creator: 'Creator', developer: 'Developer', researcher: 'Researcher', product: 'Product / Design', other: 'Other' },
};

function formatDate(value: string | null, locale: 'zh' | 'en') {
  if (!value) return '—';
  return new Intl.DateTimeFormat(locale === 'zh' ? 'zh-CN' : 'en-US', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function AdminApplicationsPage({ user }: { user: AdminUser }) {
  const { locale } = useAdminLocale();
  const zh = locale === 'zh';
  const roles: Record<string, string> = roleLabels[locale];
  const statusLabel = (value: string) => zh ? ({ pending: '待审核', approved: '已通过', rejected: '已拒绝', sent: '已发送', failed: '发送失败', not_sent: '未发送' }[value] || value) : value.replace('_', ' ');
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
      setError(loadError instanceof Error ? loadError.message : (zh ? '无法加载申请。' : 'Unable to load applications.'));
    }
  }, [keyword, status, zh]);

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
      setError(zh ? '通过申请前，请先配置 PromptDock 下载地址。' : 'Configure the PromptDock download URL before approving applications.');
      return;
    }
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
      setNotice(`${result.message}${result.email_status === 'failed' ? (zh ? ' 邮件发送失败，可以重试。' : ' The email failed and can be retried.') : ''}`);
      setSelected(null);
      await load();
    } catch (reviewError) {
      setError(reviewError instanceof Error ? reviewError.message : (zh ? '无法审核申请。' : 'Unable to review application.'));
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
      setError(retryError instanceof Error ? retryError.message : (zh ? '无法重试邮件。' : 'Unable to retry email.'));
    } finally {
      setWorking(false);
    }
  };

  const resendApprovedEmails = async () => {
    const approved = applications.filter((item) => item.status === 'approved');
    if (user.role !== 'owner' || approved.length === 0) return;
    const confirmed = window.confirm(
      zh ? '向所有已通过的内测用户重新发送通过邮件？他们之前的反馈链接将失效并被替换。' : 'Resend the approval email to every approved Early Access user? Their previous feedback links will be replaced.',
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
      setError(resendError instanceof Error ? resendError.message : (zh ? '无法重新发送通过邮件。' : 'Unable to resend approval emails.'));
    } finally {
      setBulkWorking(false);
    }
  };

  return (
    <>
      <div className="admin-topline">
        <div><h1>{zh ? '内测申请' : 'Early Access'}</h1><p>{zh ? '审核 PromptDock 申请并查看结果邮件状态。' : 'Review PromptDock applicants and monitor decision emails.'}</p></div>
        <span className="status-badge pending">{counts.shown} {zh ? '条' : 'shown'}</span>
      </div>
      {notice && <div className="admin-alert">{notice}</div>}
      {error && <div className="admin-alert error" role="alert">{error}</div>}
      {!settings?.download_url && (
        <div className="admin-alert error">{zh ? '在设置中保存下载地址前，不能通过申请。' : 'Approvals are disabled until a download URL is saved in Settings.'}</div>
      )}
      <div className="admin-filters">
        <input type="search" placeholder={zh ? '搜索姓名、邮箱、角色或回答…' : 'Search name, email, role, or answers…'} value={keyword} onChange={(event) => setKeyword(event.target.value)} />
        <select value={status} onChange={(event) => setStatus(event.target.value)}>
          <option value="all">{zh ? '全部状态' : 'All statuses'}</option>
          <option value="pending">{zh ? '待审核' : 'Pending'}</option>
          <option value="approved">{zh ? '已通过' : 'Approved'}</option>
          <option value="rejected">{zh ? '已拒绝' : 'Rejected'}</option>
        </select>
        {user.role === 'owner' && applications.some((item) => item.status === 'approved') && (
          <button className="button button-retry" type="button" disabled={bulkWorking} onClick={resendApprovedEmails}>
            <Send size={17} />{bulkWorking ? (zh ? '正在发送…' : 'Sending…') : (zh ? '重新发送给所有已通过用户' : 'Resend to all approved')}
          </button>
        )}
      </div>
      {user.role === 'owner' && applications.some((item) => item.status === 'approved') && (
        <p className="admin-help-text">{zh ? '邮件会发送给所有已通过用户，并替换每位用户之前的专属反馈链接。' : 'Sends to every approved user and replaces each user’s previous private feedback link.'}</p>
      )}
      <div className="admin-card">
        {applications.length === 0 ? (
          <div className="empty-admin">{zh ? '没有符合筛选条件的申请。' : 'No applications match these filters.'}</div>
        ) : (
          <table className="applications-table">
            <thead><tr><th>{zh ? '申请人' : 'Applicant'}</th><th>{zh ? '角色' : 'Role'}</th><th>{zh ? '语言' : 'Locale'}</th><th>{zh ? '状态' : 'Status'}</th><th>{zh ? '邮件' : 'Email'}</th><th>{zh ? '提交时间' : 'Submitted'}</th></tr></thead>
            <tbody>
              {applications.map((item) => (
                <tr key={item.id} onClick={() => setSelected(item)}>
                  <td><div className="application-person"><strong>{item.full_name}</strong><span>{item.email}</span></div></td>
                  <td>{roles[item.role] || item.role}</td>
                  <td>{item.locale === 'zh' ? '中文' : 'English'}</td>
                  <td><span className={`status-badge ${item.status}`}>{statusLabel(item.status)}</span></td>
                  <td><span className={`status-badge ${item.latest_email_status || 'not_sent'}`}>{statusLabel(item.latest_email_status || 'not_sent')}</span></td>
                  <td>{formatDate(item.created_at, locale)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {selected && (
        <>
          <div className="drawer-backdrop" onClick={() => setSelected(null)} />
          <aside className="application-drawer" aria-label={zh ? '申请详情' : 'Application details'}>
            <div className="drawer-header">
              <div><h2>{selected.full_name}</h2><p>{selected.email}</p></div>
              <button className="icon-button" type="button" onClick={() => setSelected(null)} aria-label={zh ? '关闭' : 'Close'}><X size={19} /></button>
            </div>
            <div className="detail-grid">
              <div className="detail-item"><span>{zh ? '状态' : 'Status'}</span><strong>{statusLabel(selected.status)}</strong></div>
              <div className="detail-item"><span>{zh ? '角色' : 'Role'}</span><strong>{roles[selected.role] || selected.role}</strong></div>
              <div className="detail-item"><span>{zh ? '语言' : 'Language'}</span><strong>{selected.locale === 'zh' ? '中文' : 'English'}</strong></div>
              <div className="detail-item"><span>{zh ? '批次' : 'Cohort'}</span><strong>{selected.cohort}</strong></div>
              <div className="detail-item"><span>{zh ? '提交时间' : 'Submitted'}</span><strong>{formatDate(selected.created_at, locale)}</strong></div>
              <div className="detail-item"><span>{zh ? '结果邮件' : 'Decision email'}</span><strong>{statusLabel(selected.latest_email_status || 'not_sent')}</strong></div>
            </div>
            <div className="detail-block"><span>{zh ? '使用场景' : 'Use case'}</span><p>{selected.use_case}</p></div>
            <div className="detail-block"><span>{zh ? '申请原因' : 'Motivation'}</span><p>{selected.motivation}</p></div>
            {selected.latest_email_error && <div className="admin-alert error">{selected.latest_email_error}</div>}
            {selected.status === 'pending' ? (
              <div className="review-form">
                <label>{zh ? '内部备注' : 'Internal note'}<textarea value={internalNote} maxLength={2000} onChange={(event) => setInternalNote(event.target.value)} placeholder={zh ? '仅管理员可见。' : 'Visible only to administrators.'} /></label>
                <label>{zh ? '给申请人的留言（可选）' : 'Optional applicant message'}<textarea value={applicantMessage} maxLength={1500} onChange={(event) => setApplicantMessage(event.target.value)} placeholder={zh ? '将包含在结果邮件中。' : 'Included in the decision email.'} /></label>
                <div className="review-actions">
                  <button className="button button-approve" type="button" disabled={working || !settings?.download_url} onClick={() => review('approved')}>{zh ? '通过' : 'Approve'}</button>
                  <button className="button button-reject" type="button" disabled={working} onClick={() => review('rejected')}>{zh ? '拒绝' : 'Reject'}</button>
                </div>
              </div>
            ) : (
              <>
                <div className="detail-block"><span>{zh ? '审核人' : 'Reviewed by'}</span><p>{selected.reviewer_name || '—'} · {formatDate(selected.reviewed_at, locale)}</p></div>
                {selected.internal_note && <div className="detail-block"><span>{zh ? '内部备注' : 'Internal note'}</span><p>{selected.internal_note}</p></div>}
                {selected.applicant_message && <div className="detail-block"><span>{zh ? '给申请人的留言' : 'Applicant message'}</span><p>{selected.applicant_message}</p></div>}
                {selected.latest_email_status !== 'sent' && (
                  <button className="button button-retry" type="button" disabled={working} onClick={retryEmail}>
                    <RotateCw size={17} />{selected.latest_email_status === 'failed' ? (zh ? '重试结果邮件' : 'Retry decision email') : (zh ? '发送结果邮件' : 'Send decision email')}
                  </button>
                )}
                {selected.latest_email_status === 'sent' && <div className="button button-retry"><Mail size={17} />{zh ? '结果邮件已发送' : 'Decision email sent'}</div>}
              </>
            )}
          </aside>
        </>
      )}
    </>
  );
}
