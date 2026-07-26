import { FormEvent, useEffect, useReducer, useState } from 'react';
import { ArrowDown, ArrowRight, Check, Command, FolderHeart, HardDrive, Leaf, Search, ShieldCheck, Sparkles } from 'lucide-react';
import Plasma from '../components/Plasma';
import TextType from '../components/TextType';
import { api } from '../lib/api';
import { copy, Locale } from '../content';

type FormState = {
  full_name: string;
  email: string;
  role: string;
  use_case: string;
  motivation: string;
  consent: boolean;
  company_website: string;
};

const initialForm: FormState = {
  full_name: '',
  email: '',
  role: '',
  use_case: '',
  motivation: '',
  consent: false,
  company_website: '',
};

type FormFieldAction = {
  [Field in keyof FormState]: { type: 'field'; field: Field; value: FormState[Field] };
}[keyof FormState];

type FormAction = FormFieldAction | { type: 'reset' };

function formReducer(state: FormState, action: FormAction): FormState {
  if (action.type === 'reset') return initialForm;
  return { ...state, [action.field]: action.value };
}

export default function PublicSite() {
  const [locale, setLocale] = useState<Locale>(() => {
    const saved = window.localStorage.getItem('cuegrove-locale');
    if (saved === 'zh' || saved === 'en') return saved;
    return navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en';
  });
  const [form, dispatchForm] = useReducer(formReducer, initialForm);
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');
  const t = copy[locale];

  useEffect(() => {
    document.documentElement.lang = locale === 'zh' ? 'zh-CN' : 'en';
    window.localStorage.setItem('cuegrove-locale', locale);
  }, [locale]);

  const toggleLocale = () => setLocale((value) => (value === 'zh' ? 'en' : 'zh'));

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (
      !form.full_name.trim() ||
      !form.email.trim() ||
      !form.role ||
      !form.use_case.trim() ||
      !form.motivation.trim() ||
      !form.consent
    ) {
      setStatus('error');
      setMessage(t.requiredError);
      return;
    }

    setStatus('submitting');
    setMessage('');
    try {
      await api('/early-access/applications', {
        method: 'POST',
        body: JSON.stringify({ ...form, locale }),
      });
      dispatchForm({ type: 'reset' });
      setStatus('success');
    } catch (error) {
      setStatus('error');
      setMessage(error instanceof Error ? error.message : t.formError);
    }
  };

  return (
    <main>
      <header className="site-header">
        <a className="brand-lockup" href="#top" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </a>
        <nav className="main-nav" aria-label="Primary">
          <a href="#philosophy">{t.navStory}</a>
          <a href="#promptdock">{t.navProduct}</a>
          <a className="nav-apply" href="#early-access">{t.navApply}</a>
          <button type="button" className="language-button" onClick={toggleLocale} aria-label="Switch language">
            {t.languageName}
          </button>
        </nav>
      </header>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <div className="eyebrow"><Leaf size={15} />{t.eyebrow}</div>
          <TextType
            key={locale}
            as="h1"
            text={t.headline}
            typingSpeed={72}
            initialDelay={260}
            loop={false}
            showCursor
            cursorCharacter="|"
            cursorBlinkDuration={0.7}
            className="hero-type-title"
            cursorClassName="hero-type-cursor"
            aria-label={t.headline.replace(/\n/g, ' ')}
          />
          <p>{t.heroBody}</p>
          <div className="hero-actions">
            <a className="button button-primary" href="#early-access">
              {t.heroPrimary}<ArrowRight size={18} />
            </a>
            <a className="text-link" href="#philosophy">
              {t.heroSecondary}<ArrowDown size={16} />
            </a>
          </div>
          <div className="hero-signals" aria-label="Product principles">
            <span><Check size={14} />{t.signalPrivate}</span>
            <span><Check size={14} />{t.signalNative}</span>
            <span><Check size={14} />{t.signalCalm}</span>
          </div>
        </div>
        <div className="hero-art" aria-hidden="true">
          <Plasma />
          <div className="hero-orbit orbit-one" />
          <div className="hero-orbit orbit-two" />
          <div className="hero-mark">
            <img src="/cuegrove-logo.png" alt="" />
          </div>
          <div className="floating-note note-one"><Sparkles size={16} />Ideas, kept close.</div>
          <div className="floating-note note-two"><ShieldCheck size={16} />Private by default.</div>
        </div>
      </section>

      <section className="story-section" id="philosophy">
        <div className="shell story-intro">
          <div>
            <span className="section-kicker">{t.storyKicker}</span>
            <h2>{t.storyTitle}</h2>
          </div>
          <p>{t.storyBody}</p>
        </div>
        <div className="shell values-grid">
          <article>
            <div className="value-number">01</div>
            <div className="value-icon"><HardDrive size={22} /></div>
            <h3>{t.valueOneTitle}</h3>
            <p>{t.valueOneBody}</p>
          </article>
          <article>
            <div className="value-number">02</div>
            <div className="value-icon"><Command size={22} /></div>
            <h3>{t.valueTwoTitle}</h3>
            <p>{t.valueTwoBody}</p>
          </article>
          <article>
            <div className="value-number">03</div>
            <div className="value-icon"><Leaf size={22} /></div>
            <h3>{t.valueThreeTitle}</h3>
            <p>{t.valueThreeBody}</p>
          </article>
        </div>
      </section>

      <section className="product-section shell" id="promptdock">
        <div className="product-visual">
          <div className="product-glow" />
          <img className="promptdock-icon" src="/promptdock-icon.png" alt="PromptDock app icon" />
          <div className="quick-search-card">
            <Search size={17} />
            <span>Search prompts…</span>
            <kbd>⇧⌘P</kbd>
          </div>
          <div className="category-chip chip-one">✍️ Writing</div>
          <div className="category-chip chip-two">💻 Development</div>
        </div>
        <div className="product-copy">
          <span className="section-kicker">{t.productKicker}</span>
          <h2>{t.productTitle}</h2>
          <p className="product-lead">{t.productLead}</p>
          <p className="product-body">{t.productBody}</p>
          <div className="feature-list">
            <div><Search size={20} /><span><strong>{t.featureSearch}</strong>{t.featureSearchBody}</span></div>
            <div><FolderHeart size={20} /><span><strong>{t.featureOrganize}</strong>{t.featureOrganizeBody}</span></div>
            <div><ShieldCheck size={20} /><span><strong>{t.featurePrivacy}</strong>{t.featurePrivacyBody}</span></div>
          </div>
          <div className="requirement-pill"><span className="status-dot" />{t.macRequirement}</div>
        </div>
      </section>

      <section className="apply-section" id="early-access">
        <div className="shell apply-grid">
          <div className="apply-intro">
            <span className="section-kicker light">{t.applyKicker}</span>
            <h2>{t.applyTitle}</h2>
            <p>{t.applyBody}</p>
            <div className="apply-rings" aria-hidden="true"><span /><span /><span /></div>
          </div>
          <div className="application-card">
            {status === 'success' ? (
              <div className="success-state" role="status">
                <div className="success-icon"><Leaf size={30} /></div>
                <h3>{t.successTitle}</h3>
                <p>{t.successBody}</p>
                <button type="button" className="button button-secondary" onClick={() => setStatus('idle')}>
                  {locale === 'zh' ? '提交另一份申请' : 'Submit another application'}
                </button>
              </div>
            ) : (
              <form onSubmit={submit} noValidate>
                <div className="form-row">
                  <label>
                    <span>{t.formName}</span>
                    <input
                      autoComplete="name"
                      maxLength={80}
                      value={form.full_name}
                      onChange={(event) => dispatchForm({ type: 'field', field: 'full_name', value: event.target.value })}
                      required
                    />
                  </label>
                  <label>
                    <span>{t.formEmail}</span>
                    <input
                      type="email"
                      autoComplete="email"
                      maxLength={160}
                      value={form.email}
                      onChange={(event) => dispatchForm({ type: 'field', field: 'email', value: event.target.value })}
                      required
                    />
                  </label>
                </div>
                <label>
                  <span>{t.formRole}</span>
                  <select value={form.role} onChange={(event) => dispatchForm({ type: 'field', field: 'role', value: event.target.value })} required>
                    <option value="">{t.formRolePlaceholder}</option>
                    {Object.entries(t.roles).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select>
                </label>
                <label>
                  <span>{t.formUseCase}</span>
                  <textarea
                    rows={3}
                    maxLength={1500}
                    placeholder={t.formUseCasePlaceholder}
                    value={form.use_case}
                    onChange={(event) => dispatchForm({ type: 'field', field: 'use_case', value: event.target.value })}
                    required
                  />
                </label>
                <label>
                  <span>{t.formReason}</span>
                  <textarea
                    rows={3}
                    maxLength={1500}
                    placeholder={t.formReasonPlaceholder}
                    value={form.motivation}
                    onChange={(event) => dispatchForm({ type: 'field', field: 'motivation', value: event.target.value })}
                    required
                  />
                </label>
                <label className="honeypot" aria-hidden="true">
                  Company website
                  <input
                    aria-hidden="true"
                    tabIndex={-1}
                    autoComplete="off"
                    value={form.company_website}
                    onChange={(event) => dispatchForm({ type: 'field', field: 'company_website', value: event.target.value })}
                  />
                </label>
                <label className="consent-row">
                  <input
                    type="checkbox"
                    checked={form.consent}
                    onChange={(event) => dispatchForm({ type: 'field', field: 'consent', value: event.target.checked })}
                    required
                  />
                  <span>{t.consent}</span>
                </label>
                <p className="privacy-copy">{t.privacy}</p>
                {status === 'error' && <p className="form-message error" role="alert">{message || t.formError}</p>}
                <button className="button button-submit" type="submit" disabled={status === 'submitting'}>
                  {status === 'submitting' ? t.submitting : t.submit}<ArrowRight size={18} />
                </button>
              </form>
            )}
          </div>
        </div>
      </section>

      <footer className="site-footer shell">
        <div className="footer-brand">
          <div className="brand-lockup">
            <img src="/cuegrove-logo.png" alt="" />
            <span>CueGrove</span>
          </div>
          <p>{t.footerLine}</p>
        </div>
        <div className="footer-links">
          <a href="#early-access">{t.footerPrivacy}</a>
          <a href="/admin/login">{t.footerAdmin}</a>
          <span>© {new Date().getFullYear()} CueGrove</span>
        </div>
      </footer>
    </main>
  );
}
