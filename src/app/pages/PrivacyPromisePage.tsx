import { useEffect } from 'react';
import {
  ArrowLeft,
  Check,
  Database,
  EyeOff,
  HardDrive,
  Leaf,
  Mail,
  RefreshCcw,
  ShieldCheck,
} from 'lucide-react';
import { Link } from 'react-router-dom';
import { usePublicLocale } from '../lib/locale';

const privacyCopy = {
  zh: {
    languageName: 'EN',
    home: '返回首页',
    eyebrow: 'CueGrove Privacy Promise',
    title: '隐私不是设置，\n而是产品的边界。',
    intro:
      '我们用尽量少的数据提供安静、可靠的个人工具。这份承诺用清楚的语言说明什么留在你的设备上、网站会处理什么，以及你始终拥有的选择。',
    status: '公开承诺 · 版本 1.0',
    effective: '生效日期：2026 年 7 月 27 日',
    principlesLabel: '我们的原则',
    principles: [
      {
        title: '本地优先',
        body: 'PromptDock 的提示词、分类、图标和小组件快照默认保存在你的 Mac，不需要产品账号。',
      },
      {
        title: '不出售数据',
        body: '我们不出售、出租或交换个人信息，也不使用申请资料建立广告画像。',
      },
      {
        title: '只取所需',
        body: '只有当一项数据确实用于提供、保护或改进你主动使用的服务时，我们才会处理它。',
      },
      {
        title: '清楚说明',
        body: '当产品的数据边界发生实质变化时，我们会更新本页，并说明变化内容和生效时间。',
      },
    ],
    boundaryKicker: '数据边界',
    boundaryTitle: '本机产品与网站服务，边界不同。',
    boundaryIntro:
      '“本地优先”描述的是 PromptDock 产品内容。Early Access 申请需要经过 CueGrove 网站提交，因此会由网站服务器处理。',
    productLabel: 'PromptDock 应用',
    productTitle: '你的内容留在你的 Mac',
    productBody:
      '当前版本不包含账号、广告、分析、网络上传或云同步。PromptDock 不会主动上传你的提示词或分类资料。',
    productPoints: [
      '提示词、分类、Emoji、分类图片与小组件快照保存在本机',
      '导入和导出的 JSON 备份由你选择保存位置',
      'Time Machine、磁盘同步或其他系统备份由你的 macOS 设置决定',
    ],
    websiteLabel: 'CueGrove 网站',
    websiteTitle: '申请资料只用于你提出的申请',
    websiteBody:
      '提交 Early Access 时，我们会保存你填写的信息，以便审核申请、发送结果并管理内测参与。',
    websitePoints: [
      '保存姓名、邮箱、角色、使用场景、参与原因、界面语言和同意时间',
      '申请记录不会附带保存原始 IP 地址',
      '网站语言偏好只保存在你的浏览器中',
      'Cloudflare、服务器与邮件系统会处理提供和保护服务所需的网络、安全及投递数据',
    ],
    practiceKicker: '具体做法',
    practiceTitle: '我们如何兑现这份承诺',
    practices: [
      {
        title: '没有广告追踪',
        body: '我们不放置广告追踪器，不进行跨站行为画像，也不因为你拒绝营销追踪而降低产品体验。',
      },
      {
        title: '必要的安全处理',
        body: 'Cloudflare Turnstile、安全 Cookie、访问日志和限流用于抵御滥用、保护申请与管理功能，不用于广告投放。',
      },
      {
        title: '有限的服务共享',
        body: '数据只会在提供托管、安全防护和邮件投递所必需的范围内由服务基础设施处理，或在法律明确要求时披露。',
      },
      {
        title: '不过度保留',
        body: '申请资料仅在管理 Early Access、处理相关沟通以及满足必要安全或法律要求期间保留；不再需要时会被删除或去标识化。',
      },
    ],
    choicesKicker: '你的选择',
    choicesTitle: '你的资料，由你决定。',
    choicesBody:
      '你可以要求我们确认是否持有你的申请资料，并在适用情况下请求更正或删除。你也可以随时要求停止与 Early Access 相关的非必要联系。',
    choicePoints: ['查询或更正申请信息', '请求删除申请记录', '撤回后续非必要邮件联系'],
    contactLabel: '隐私请求',
    contactEmail: 'mooncci@cuegroveapp.com',
    responseNote: '请从申请时使用的邮箱联系我们，以便核验请求。',
    limitsKicker: '诚实说明',
    limitsTitle: '我们不会把承诺写得比产品更大。',
    limitsBody:
      '这是一份公开的产品承诺，不替代适用法律要求的正式隐私政策。链接到其他网站、你选择的备份位置以及 macOS 自身服务，适用其各自的隐私规则。我们也无法保证任何系统绝对安全，但会持续减少数据、限制访问并及时修复已知问题。',
    changesTitle: '这是一份持续维护的承诺',
    changesBody:
      '如果未来加入账号、同步、分析或其他会改变数据边界的功能，我们会在启用前更新说明；实质性变化会标明新版本和生效日期。',
    homeFooter: '首页',
    security: '安全承诺',
    github: 'GitHub',
    copyrightLine: '安静、可靠、尊重隐私的个人工具',
  },
  en: {
    languageName: '中文',
    home: 'Back home',
    eyebrow: 'CueGrove Privacy Promise',
    title: 'Privacy is not a setting.\nIt is a product boundary.',
    intro:
      'We use as little data as possible to provide calm, dependable personal tools. This promise explains what stays on your device, what the website processes, and the choices that remain yours.',
    status: 'Public commitment · Version 1.0',
    effective: 'Effective July 27, 2026',
    principlesLabel: 'Our principles',
    principles: [
      {
        title: 'Local first',
        body: 'PromptDock keeps prompts, categories, icons, and widget snapshots on your Mac by default, without requiring a product account.',
      },
      {
        title: 'Never sold',
        body: 'We do not sell, rent, or trade personal information, and we do not use application data to build advertising profiles.',
      },
      {
        title: 'Only what is needed',
        body: 'We process data only when it is genuinely needed to provide, protect, or improve a service you choose to use.',
      },
      {
        title: 'Plainly explained',
        body: 'When the product’s data boundaries materially change, we will update this page and explain what changed and when it takes effect.',
      },
    ],
    boundaryKicker: 'Data boundaries',
    boundaryTitle: 'The local app and the website have different boundaries.',
    boundaryIntro:
      '“Local first” describes content inside PromptDock. An Early Access application is submitted through the CueGrove website and therefore must be processed by the website server.',
    productLabel: 'PromptDock app',
    productTitle: 'Your content stays on your Mac',
    productBody:
      'The current app has no account, advertising, analytics, network upload, or cloud sync. PromptDock does not actively upload your prompts or category data.',
    productPoints: [
      'Prompts, categories, emoji, category images, and widget snapshots are stored locally',
      'You choose where exported and imported JSON backups are kept',
      'Time Machine, disk sync, and other system backups are controlled by your macOS settings',
    ],
    websiteLabel: 'CueGrove website',
    websiteTitle: 'Application data is used for the application you requested',
    websiteBody:
      'When you apply for Early Access, we store what you submit so we can review it, send a decision, and manage preview participation.',
    websitePoints: [
      'We store your name, email, role, use case, motivation, interface language, and consent time',
      'The application record is not stored with your raw IP address',
      'Your website language preference is stored only in your browser',
      'Cloudflare, our server, and our mail system process network, security, and delivery data needed to provide and protect the service',
    ],
    practiceKicker: 'Our practices',
    practiceTitle: 'How we put this promise into practice',
    practices: [
      {
        title: 'No advertising tracking',
        body: 'We do not place advertising trackers, build cross-site behavioral profiles, or reduce the product experience when you decline marketing tracking.',
      },
      {
        title: 'Necessary security processing',
        body: 'Cloudflare Turnstile, security cookies, access logs, and rate limits help prevent abuse and protect application and admin features. They are not used for advertising.',
      },
      {
        title: 'Limited service sharing',
        body: 'Data is processed by service infrastructure only as needed for hosting, security, and email delivery, or disclosed when clearly required by law.',
      },
      {
        title: 'No unnecessary retention',
        body: 'Application data is kept only while needed to manage Early Access, related communication, and necessary security or legal obligations, then deleted or de-identified.',
      },
    ],
    choicesKicker: 'Your choices',
    choicesTitle: 'Your information remains yours.',
    choicesBody:
      'You may ask whether we hold your application data and, where applicable, request correction or deletion. You may also ask us to stop non-essential Early Access communication at any time.',
    choicePoints: ['Access or correct application information', 'Request deletion of an application record', 'Withdraw from non-essential follow-up email'],
    contactLabel: 'Privacy requests',
    contactEmail: 'mooncci@cuegroveapp.com',
    responseNote: 'Please contact us from the address used in your application so we can verify the request.',
    limitsKicker: 'Honest limits',
    limitsTitle: 'We will not make this promise broader than the product.',
    limitsBody:
      'This is a public product commitment and does not replace a formal privacy policy where one is required by law. Other websites, backup locations you choose, and macOS services follow their own privacy terms. No system can be guaranteed absolutely secure, but we will keep reducing data, limiting access, and fixing known issues promptly.',
    changesTitle: 'A promise we maintain',
    changesBody:
      'If we introduce accounts, sync, analytics, or another feature that changes a data boundary, we will update this explanation before enabling it. Material changes will receive a new version and effective date.',
    homeFooter: 'Home',
    security: 'Security Commitment',
    github: 'GitHub',
    copyrightLine: 'Calm, dependable tools that respect your privacy',
  },
} as const;

const principleIcons = [HardDrive, EyeOff, Database, RefreshCcw];

export default function PrivacyPromisePage() {
  const [locale, setLocale] = usePublicLocale();
  const t = privacyCopy[locale];

  useEffect(() => {
    document.documentElement.lang = locale === 'zh' ? 'zh-CN' : 'en';
    document.title = locale === 'zh'
      ? '隐私承诺 — CueGrove'
      : 'Privacy Promise — CueGrove';
  }, [locale]);

  useEffect(() => {
    window.scrollTo({ top: 0 });
  }, []);

  return (
    <main className="privacy-promise-page">
      <header className="site-header policy-header">
        <Link className="brand-lockup" to="/" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <nav className="policy-nav" aria-label={locale === 'zh' ? '隐私页面导航' : 'Privacy page navigation'}>
          <Link className="policy-home-link" to="/">
            <ArrowLeft size={16} />{t.home}
          </Link>
          <button
            type="button"
            className="language-button"
            onClick={() => setLocale((value) => (value === 'zh' ? 'en' : 'zh'))}
            aria-label="Switch language"
          >
            {t.languageName}
          </button>
        </nav>
      </header>

      <section className="privacy-hero shell">
        <div className="privacy-hero-copy">
          <span className="section-kicker"><Leaf size={15} />{t.eyebrow}</span>
          <h1>{t.title}</h1>
          <p>{t.intro}</p>
          <div className="privacy-version">
            <span><ShieldCheck size={16} />{t.status}</span>
            <span>{t.effective}</span>
          </div>
        </div>
        <div className="privacy-hero-mark" aria-hidden="true">
          <div className="privacy-mark-ring privacy-mark-ring-one" />
          <div className="privacy-mark-ring privacy-mark-ring-two" />
          <img src="/cuegrove-logo.png" alt="" />
        </div>
      </section>

      <section className="privacy-principles shell" aria-labelledby="privacy-principles-title">
        <span className="section-kicker" id="privacy-principles-title">{t.principlesLabel}</span>
        <div className="privacy-principles-grid">
          {t.principles.map((principle, index) => {
            const PrincipleIcon = principleIcons[index];
            return (
              <article key={principle.title}>
                <div className="privacy-card-icon"><PrincipleIcon size={21} /></div>
                <h2>{principle.title}</h2>
                <p>{principle.body}</p>
              </article>
            );
          })}
        </div>
      </section>

      <section className="privacy-boundary-section">
        <div className="shell">
          <div className="privacy-section-heading">
            <span className="section-kicker">{t.boundaryKicker}</span>
            <h2>{t.boundaryTitle}</h2>
            <p>{t.boundaryIntro}</p>
          </div>
          <div className="privacy-boundary-grid">
            <article className="privacy-boundary-card local">
              <span className="privacy-card-label"><HardDrive size={16} />{t.productLabel}</span>
              <h3>{t.productTitle}</h3>
              <p>{t.productBody}</p>
              <ul>
                {t.productPoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
              </ul>
            </article>
            <article className="privacy-boundary-card website">
              <span className="privacy-card-label"><Database size={16} />{t.websiteLabel}</span>
              <h3>{t.websiteTitle}</h3>
              <p>{t.websiteBody}</p>
              <ul>
                {t.websitePoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
              </ul>
            </article>
          </div>
        </div>
      </section>

      <section className="privacy-practices shell">
        <div className="privacy-section-heading">
          <span className="section-kicker">{t.practiceKicker}</span>
          <h2>{t.practiceTitle}</h2>
        </div>
        <div className="privacy-practice-list">
          {t.practices.map((practice, index) => (
            <article key={practice.title}>
              <span>{String(index + 1).padStart(2, '0')}</span>
              <div>
                <h3>{practice.title}</h3>
                <p>{practice.body}</p>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="privacy-choice-section">
        <div className="shell privacy-choice-grid">
          <div>
            <span className="section-kicker light">{t.choicesKicker}</span>
            <h2>{t.choicesTitle}</h2>
            <p>{t.choicesBody}</p>
            <ul>
              {t.choicePoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
            </ul>
          </div>
          <aside className="privacy-contact-card">
            <div className="privacy-card-icon"><Mail size={22} /></div>
            <span>{t.contactLabel}</span>
            <a href={`mailto:${t.contactEmail}`}>{t.contactEmail}</a>
            <p>{t.responseNote}</p>
          </aside>
        </div>
      </section>

      <section className="privacy-honesty shell">
        <article>
          <span className="section-kicker">{t.limitsKicker}</span>
          <h2>{t.limitsTitle}</h2>
          <p>{t.limitsBody}</p>
        </article>
        <article className="privacy-change-note">
          <RefreshCcw size={23} />
          <div>
            <h3>{t.changesTitle}</h3>
            <p>{t.changesBody}</p>
          </div>
        </article>
      </section>

      <footer className="site-footer shell">
        <div className="footer-brand">
          <div className="brand-lockup">
            <img src="/cuegrove-logo.png" alt="" />
            <span>CueGrove</span>
          </div>
          <p>{t.copyrightLine}</p>
        </div>
        <div className="footer-links">
          <Link to="/">{t.homeFooter}</Link>
          <Link to="/security">{t.security}</Link>
          <a href="https://github.com/13304930782/PromptDock" target="_blank" rel="noreferrer">{t.github}</a>
          <span>© {new Date().getFullYear()} CueGrove</span>
        </div>
      </footer>
    </main>
  );
}
