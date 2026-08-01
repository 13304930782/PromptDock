import { FormEvent, useEffect, useState } from 'react';
import { Check, Leaf } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../lib/api';

const categories = [
  ['bug', 'Bug or crash'],
  ['idea', 'Feature idea'],
  ['ux', 'Usability'],
  ['performance', 'Performance'],
  ['other', 'Other'],
] as const;

export default function FeedbackPage() {
  const { token = '' } = useParams();
  const [name, setName] = useState('');
  const [category, setCategory] = useState('bug');
  const [title, setTitle] = useState('');
  const [details, setDetails] = useState('');
  const [steps, setSteps] = useState('');
  const [expected, setExpected] = useState('');
  const [actual, setActual] = useState('');
  const [device, setDevice] = useState('');
  const [macosVersion, setMacosVersion] = useState('');
  const [appBuild, setAppBuild] = useState('');
  const [state, setState] = useState<'loading' | 'ready' | 'submitting' | 'submitted' | 'error'>('loading');
  const [message, setMessage] = useState('');

  useEffect(() => {
    document.title = 'PromptDock Feedback — CueGrove';
    api<{ feedback: { name: string } }>(`/feedback/${token}`)
      .then((result) => { setName(result.feedback.name); setState('ready'); })
      .catch((error) => { setMessage(error instanceof Error ? error.message : 'This feedback link is invalid or expired.'); setState('error'); });
  }, [token]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setState('submitting');
    try {
      await api(`/feedback/${token}`, {
        method: 'POST',
        body: JSON.stringify({ category, title, details, steps, expected, actual, device, macos_version: macosVersion, app_build: appBuild }),
      });
      setState('submitted');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Unable to send feedback.');
      setState('error');
    }
  };

  if (state === 'loading') return <main className="feedback-page shell"><p>Loading feedback form…</p></main>;
  if (state === 'error') return <main className="feedback-page shell"><h1>Feedback link unavailable</h1><p>{message}</p><Link className="button button-primary" to="/">Back to CueGrove</Link></main>;
  if (state === 'submitted') return <main className="feedback-page shell"><div className="feedback-card"><Leaf size={28} /><Check size={28} /><h1>Thank you, {name}.</h1><p>Your feedback is now in the PromptDock testing queue.</p><Link className="button button-primary" to="/">Back to CueGrove</Link></div></main>;

  return (
    <main className="feedback-page shell">
      <div className="eyebrow"><Leaf size={15} /> PromptDock Early Access</div>
      <h1>Tell us what happened</h1>
      <p className="feedback-intro">Hi {name}. Keep the report factual and concise. Please do not include private prompt content.</p>
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
        {message && <p className="form-error" role="alert">{message}</p>}
        <button className="button button-primary" type="submit" disabled={state === 'submitting'}>{state === 'submitting' ? 'Sending…' : 'Send feedback'}</button>
      </form>
    </main>
  );
}
