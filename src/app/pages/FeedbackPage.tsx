import { FormEvent, useCallback, useEffect, useState } from 'react';
import { Check, Leaf, Send } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../lib/api';
import type { FeedbackReport } from '../types';

const categories = [
  ['bug', 'Bug or crash'],
  ['idea', 'Feature idea'],
  ['ux', 'Usability'],
  ['performance', 'Performance'],
  ['other', 'Other'],
] as const;

function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

export default function FeedbackPage() {
  const { token = '' } = useParams();
  const [name, setName] = useState('');
  const [reports, setReports] = useState<FeedbackReport[]>([]);
  const [category, setCategory] = useState('bug');
  const [title, setTitle] = useState('');
  const [details, setDetails] = useState('');
  const [steps, setSteps] = useState('');
  const [expected, setExpected] = useState('');
  const [actual, setActual] = useState('');
  const [device, setDevice] = useState('');
  const [macosVersion, setMacosVersion] = useState('');
  const [appBuild, setAppBuild] = useState('');
  const [reply, setReply] = useState<Record<number, string>>({});
  const [state, setState] = useState<'loading' | 'ready' | 'submitting' | 'error'>('loading');
  const [workingReport, setWorkingReport] = useState<number | null>(null);
  const [message, setMessage] = useState('');
  const [notice, setNotice] = useState('');

  const load = useCallback(async (quiet = false) => {
    try {
      const result = await api<{ feedback: { name: string; reports: FeedbackReport[] } }>(`/feedback/${token}`);
      setName(result.feedback.name);
      setReports(result.feedback.reports);
      setState('ready');
      if (!quiet) setMessage('');
    } catch (error) {
      if (!quiet) {
        setMessage(error instanceof Error ? error.message : 'This feedback link is invalid or expired.');
        setState('error');
      }
    }
  }, [token]);

  useEffect(() => {
    document.title = 'PromptDock Feedback — CueGrove';
    load();
  }, [load]);

  useEffect(() => {
    if (state !== 'ready') return undefined;
    const timer = window.setInterval(() => load(true), 10_000);
    return () => window.clearInterval(timer);
  }, [load, state]);

  useEffect(() => {
    if (reports.length && window.location.hash.startsWith('#report-')) {
      document.getElementById(window.location.hash.slice(1))?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [reports.length]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setState('submitting');
    setMessage('');
    try {
      const result = await api<{ email_status: string }>(`/feedback/${token}`, {
        method: 'POST',
        body: JSON.stringify({ category, title, details, steps, expected, actual, device, macos_version: macosVersion, app_build: appBuild }),
        timeoutMs: 130_000,
      });
      setTitle(''); setDetails(''); setSteps(''); setExpected(''); setActual('');
      setNotice(result.email_status === 'sent' ? 'Feedback sent. The developer was notified by email.' : 'Feedback saved. You can follow its progress below.');
      await load(true);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to send feedback.');
      setState('ready');
    }
  };

  const sendReply = async (event: FormEvent, reportId: number) => {
    event.preventDefault();
    const body = reply[reportId]?.trim();
    if (!body) return;
    setWorkingReport(reportId);
    setMessage('');
    try {
      const result = await api<{ email_status: string }>(`/feedback/${token}/${reportId}/replies`, {
        method: 'POST',
        body: JSON.stringify({ body }),
        timeoutMs: 130_000,
      });
      setReply((current) => ({ ...current, [reportId]: '' }));
      setNotice(result.email_status === 'sent' ? 'Reply sent. The developer was notified by email.' : 'Reply saved.');
      await load(true);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to send reply.');
    } finally {
      setWorkingReport(null);
    }
  };

  if (state === 'loading') return <main className="feedback-page shell"><p>Loading feedback…</p></main>;
  if (state === 'error') return <main className="feedback-page shell"><h1>Feedback link unavailable</h1><p>{message}</p><Link className="button button-primary" to="/">Back to CueGrove</Link></main>;

  return (
    <main className="feedback-page feedback-portal shell">
      <div className="eyebrow"><Leaf size={15} /> PromptDock Early Access</div>
      <h1>Feedback & progress</h1>
      <p className="feedback-intro">Hi {name}. Send a new report or continue an existing conversation. Please do not include private prompt content.</p>
      {notice && <div className="feedback-notice"><Check size={18} />{notice}</div>}
      {message && <p className="form-error" role="alert">{message}</p>}

      {reports.length > 0 && <section className="feedback-history"><h2>Your feedback</h2>{reports.map((report) => (
        <article className="feedback-conversation" id={`report-${report.id}`} key={report.id}>
          <header><div><span className={`status-badge ${report.status}`}>{report.status}</span><h3>{report.title}</h3></div><time>{formatDate(report.updated_at)}</time></header>
          <div className="feedback-original"><strong>{report.category}</strong><p>{report.details}</p></div>
          <div className="feedback-thread">
            {(report.messages || []).map((item) => <article className={`feedback-message ${item.author_type}`} key={item.id}><strong>{item.author_type === 'developer' ? (item.admin_name || 'PromptDock developer') : 'You'}</strong><p>{item.body}</p><time>{formatDate(item.created_at)}</time></article>)}
          </div>
          <form className="feedback-reply-form" onSubmit={(event) => sendReply(event, report.id)}>
            <label>Your reply<textarea required maxLength={4000} value={reply[report.id] || ''} onChange={(event) => setReply((current) => ({ ...current, [report.id]: event.target.value }))} placeholder="Add details or reply to the developer…" /></label>
            <button className="button button-primary" type="submit" disabled={workingReport === report.id || !reply[report.id]?.trim()}><Send size={16} />{workingReport === report.id ? 'Sending…' : 'Reply'}</button>
          </form>
        </article>
      ))}</section>}

      <section className="feedback-new-report">
        <h2>Send new feedback</h2>
        <form className="feedback-card feedback-form" onSubmit={submit}>
          <label>Category<select value={category} onChange={(event) => setCategory(event.target.value)}>{categories.map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select></label>
          <label>Title<input required minLength={3} maxLength={160} value={title} onChange={(event) => setTitle(event.target.value)} /></label>
          <label>What happened?<textarea required minLength={10} maxLength={8000} value={details} onChange={(event) => setDetails(event.target.value)} /></label>
          <label>Steps to reproduce<textarea maxLength={4000} value={steps} onChange={(event) => setSteps(event.target.value)} /></label>
          <label>Expected result<textarea maxLength={4000} value={expected} onChange={(event) => setExpected(event.target.value)} /></label>
          <label>Actual result<textarea maxLength={4000} value={actual} onChange={(event) => setActual(event.target.value)} /></label>
          <div className="feedback-grid">
            <label>Mac model<input value={device} onChange={(event) => setDevice(event.target.value)} /></label>
            <label>macOS version<input value={macosVersion} onChange={(event) => setMacosVersion(event.target.value)} /></label>
            <label>PromptDock build<input value={appBuild} onChange={(event) => setAppBuild(event.target.value)} /></label>
          </div>
          <button className="button button-primary" type="submit" disabled={state === 'submitting'}>{state === 'submitting' ? 'Sending…' : 'Send feedback'}</button>
        </form>
      </section>
    </main>
  );
}
