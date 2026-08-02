import { useEffect } from 'react';
import {
  ArrowLeft,
  Check,
  CircleAlert,
  Code2,
  ExternalLink,
  Flag,
  LockKeyhole,
  Mail,
  ShieldCheck,
} from 'lucide-react';
import { Link } from 'react-router';
import { usePublicLocale } from '../lib/locale';

const securityCopy = {
  zh: {
    languageName: 'EN',
    home: '返回首页',
    eyebrow: 'CueGrove Secure by Design Commitment',
    title: '让安全成为默认，\n而不是用户的负\u2060担',
    intro:
      '我们把安全视为产品质量和用户责任的一部分。这份公开承诺说明 CueGrove 当前已经实施的保护、仍需完成的工作，以及发现问题时如何联系我们。',
    status: '公开承诺 · 版本 1.3',
    effective: '更新日期：2026 年 8 月 1 日',
    disclosure: '负责任披露已开放',
    noticeTitle: '关于 CISA 承诺',
    noticeBody:
      'CueGrove 目前尚不是 CISA Secure by Design Pledge 的签署方。本页是我们为申请做准备的公开路线图，不代表 CISA 的认证、认可或背书。',
    noticeLink: '查看 CISA 官方承诺',
    principlesLabel: '设计原则',
    principles: [
      {
        title: '安全默认开启',
        body: '基础保护不应依赖用户阅读加固指南，也不应作为额外付费功能提供。',
      },
      {
        title: '减少攻击面',
        body: '优先减少账号、网络连接、数据收集和长期密钥，而不是只在风险出现后增加提示。',
      },
      {
        title: '分层保护',
        body: '身份验证、授权、限流、输入校验和基础设施防护共同工作，不依赖单一控制。',
      },
      {
        title: '透明负责',
        body: '如实公开当前能力、已知差距和改进进度；修复问题时关注根因，而不只处理表面症状。',
      },
    ],
    scopeKicker: '当前范围',
    scopeTitle: '一份承诺，覆盖产品与服务',
    scopeIntro:
      '不同组件面临不同风险，因此我们分别说明 PromptDock 本地应用和 CueGrove 网站服务的安全边界。',
    appLabel: 'PromptDock macOS 应用',
    appTitle: '从更小的攻击面开始',
    appBody:
      '当前版本无需产品账号，不包含广告、分析、跟踪或云同步。可选 AI 功能只在用户确认后联网，并只发送当前需求与模板语法手册。生产构建启用 macOS App Sandbox 和 Hardened Runtime，并在持续集成中检查关键安全配置。',
    appPoints: [
      '提示词和分类资料默认保存在用户设备上',
      'API Key 保存在 macOS 钥匙串中，不进入备份或普通偏好设置',
      'AI 请求不附带已保存的提示词库、分类或本地图片',
      '没有共享默认密码，也没有远程管理入口',
      '发布构建检查应用沙箱、App Group 与隐私清单',
      '开源代码和构建流程可在 GitHub 审查',
    ],
    serviceLabel: 'CueGrove 网站',
    serviceTitle: '认真对待你交给我们的信息',
    serviceBody:
      '申请 PromptDock Early Access 不需要创建公众账号。你提交的资料只用于审核申请、发送结果，以及与你参与内测直接相关的必要联系。',
    servicePoints: [
      '不出售申请资料，也不用于广告画像',
      '只有经过授权的 CueGrove 管理人员可以处理申请',
      '审核结果会按照申请时选择的语言发送到你的邮箱',
      '不要求上传身份证件、付款资料或与申请无关的敏感信息',
      '如果收到可疑邮件或发现安全问题，可以直接联系安全报告邮箱',
    ],
    roadmapKicker: '一年路线图',
    roadmapTitle: '截至 2027 年 7 月 27 日的工作',
    roadmapIntro:
      '我们会按风险和产品阶段推进以下工作。完成状态将在本页与公开仓库中更新。',
    roadmap: [
      {
        state: '已完成',
        title: '漏洞披露入口',
        body: '发布 SECURITY.md 和标准 security.txt，建立私下报告与协调披露流程。',
      },
      {
        state: '已完成',
        title: '管理员多因素认证',
        body: '管理后台支持 TOTP 认证器、短时登录挑战、代码防重放和一次性恢复码。',
      },
      {
        state: '已完成',
        title: '软件供应链检查',
        body: '持续集成会阻止新增高危依赖、审计生产依赖、扫描完整仓库历史中的凭据，并公开处置规则与有期限的例外。',
      },
      {
        state: '计划中',
        title: '安全更新政策',
        body: '公开支持版本、严重问题响应原则和安全更新发布方式。',
      },
      {
        state: '计划中',
        title: '发布可验证性',
        body: '逐步加入软件物料清单、构建来源和可核验的发行信息。',
      },
      {
        state: '计划中',
        title: '事件证据与复盘',
        body: '完善必要的安全审计记录，并为重要安全事件发布不暴露用户数据的根因说明。',
      },
    ],
    reportKicker: '报告漏洞',
    reportTitle: '请先私下告诉我们',
    reportBody:
      '如果你认为 PromptDock、cuegroveapp.com 或相关服务存在安全问题，请不要在公开 Issue 中披露可利用细节。发送邮件时尽量包含受影响组件和版本、复现步骤、潜在影响及必要证据。',
    reportPoints: [
      '不要访问、修改或下载不属于你的数据',
      '不要进行拒绝服务、垃圾邮件或影响正常用户的测试',
      '不要发送真实密码、访问令牌或不必要的个人信息',
      '在我们确认修复或共同约定公开时间前，请保留技术细节',
    ],
    contactLabel: '安全报告邮箱',
    contactEmail: 'security@cuegroveapp.com',
    subject: '建议主题：[Security] 简短问题描述',
    response: '目标：5 个工作日内确认收到，10 个工作日内完成初步分级。',
    safeHarborTitle: '善意研究',
    safeHarborBody:
      '对于遵守上述边界、以避免伤害为目的并及时报告的善意安全研究，我们不会因为该研究本身采取法律行动。该说明不授权违反法律、侵犯第三方权益或破坏服务的行为。',
    limitsKicker: '诚实说明',
    limitsTitle: '当前安全工作的范围',
    limitsBody:
      '管理员多因素认证与供应链检查已经启用。安全更新政策和发布验证仍在推进，完成后会更新到本页。收到安全报告后，我们会确认问题、安排修复，并公布可以验证的进展。',
    repoTitle: '公开仓库与披露政策',
    repoBody: '查看源代码、构建检查、供应链安全规则和仓库级漏洞报告说明。',
    repoAction: '打开 GitHub',
    homeFooter: '首页',
    privacy: '隐私承诺',
    github: 'GitHub',
    copyrightLine: '安静、可靠、安全默认的个人工具',
  },
  en: {
    languageName: '中文',
    home: 'Back home',
    eyebrow: 'CueGrove Secure by Design Commitment',
    title: 'Make security the default,\nnot the user’s burden',
    intro:
      'We treat security as part of product quality and our responsibility to users. This public commitment explains the protections CueGrove has implemented, the work still ahead, and how to contact us when something goes wrong.',
    status: 'Public commitment · Version 1.3',
    effective: 'Updated August 1, 2026',
    disclosure: 'Responsible disclosure is open',
    noticeTitle: 'About the CISA pledge',
    noticeBody:
      'CueGrove is not currently a signer of the CISA Secure by Design Pledge. This page is our public preparation roadmap, not a CISA certification, approval, or endorsement.',
    noticeLink: 'Read the official CISA pledge',
    principlesLabel: 'Design principles',
    principles: [
      {
        title: 'Secure by default',
        body: 'Baseline protection should not depend on customers reading a hardening guide or paying for a security add-on.',
      },
      {
        title: 'Reduce attack surface',
        body: 'We first reduce accounts, network connections, data collection, and long-lived secrets instead of adding warnings after risk appears.',
      },
      {
        title: 'Layered protection',
        body: 'Authentication, authorization, rate limits, validation, and infrastructure defenses work together rather than relying on one control.',
      },
      {
        title: 'Transparent ownership',
        body: 'We state current capabilities, known gaps, and progress plainly, and address root causes instead of only treating symptoms.',
      },
    ],
    scopeKicker: 'Current scope',
    scopeTitle: 'One commitment across product and service',
    scopeIntro:
      'Different components face different risks, so we describe the security boundaries of the local PromptDock app and the CueGrove website separately.',
    appLabel: 'PromptDock for macOS',
    appTitle: 'Starting with a smaller attack surface',
    appBody:
      'The current release requires no product account and has no advertising, analytics, tracking, or cloud sync. Optional AI features connect only after user confirmation and send only the current requirement and template syntax guide. Production builds use the macOS App Sandbox and Hardened Runtime, with key security settings checked in continuous integration.',
    appPoints: [
      'Prompts and category data stay on the user’s device by default',
      'API keys are stored in the macOS Keychain, not in backups or ordinary preferences',
      'AI requests exclude saved prompt libraries, categories, and local images',
      'There are no shared default passwords or remote administration endpoints',
      'Release builds check the app sandbox, App Group, and privacy manifest',
      'Source code and build checks are open for review on GitHub',
    ],
    serviceLabel: 'CueGrove website',
    serviceTitle: 'Taking care of what you share with us',
    serviceBody:
      'Applying for PromptDock Early Access does not require a public account. We use the information you submit only to review your application, send the outcome, and contact you when it directly relates to the early-access program.',
    servicePoints: [
      'Application data is never sold or used for advertising profiles',
      'Only authorized CueGrove administrators can review applications',
      'We send the decision in the language selected on the application',
      'We do not ask for identity documents, payment details, or unrelated sensitive information',
      'Suspicious messages and security concerns can be reported directly to our security mailbox',
    ],
    roadmapKicker: 'One-year roadmap',
    roadmapTitle: 'Work through July 27, 2027',
    roadmapIntro:
      'We will sequence this work according to risk and product stage. Completion status will be updated here and in the public repository.',
    roadmap: [
      {
        state: 'Complete',
        title: 'Vulnerability disclosure channel',
        body: 'Publish SECURITY.md and a standard security.txt with a private reporting and coordinated disclosure process.',
      },
      {
        state: 'Complete',
        title: 'Multi-factor authentication for administrators',
        body: 'Administration supports TOTP authenticators, short-lived login challenges, code replay protection, and one-time recovery codes.',
      },
      {
        state: 'Complete',
        title: 'Software supply-chain checks',
        body: 'Continuous integration blocks newly introduced high-risk dependencies, audits production packages, scans full repository history for credentials, and publishes handling rules and time-limited exceptions.',
      },
      {
        state: 'Planned',
        title: 'Security update policy',
        body: 'Publish supported versions, principles for responding to severe issues, and how security updates are delivered.',
      },
      {
        state: 'Planned',
        title: 'Verifiable releases',
        body: 'Progressively add software bills of materials, build provenance, and verifiable release information.',
      },
      {
        state: 'Planned',
        title: 'Incident evidence and learning',
        body: 'Improve necessary security audit records and publish root-cause notes for significant incidents without exposing user data.',
      },
    ],
    reportKicker: 'Report a vulnerability',
    reportTitle: 'Please tell us privately first',
    reportBody:
      'If you believe PromptDock, cuegroveapp.com, or a related service has a security issue, please do not disclose exploitable details in a public issue. Include the affected component and version, reproduction steps, potential impact, and only the evidence needed to understand the report.',
    reportPoints: [
      'Do not access, modify, or download data that is not yours',
      'Do not perform denial-of-service, spam, or testing that affects normal users',
      'Do not send real passwords, access tokens, or unnecessary personal information',
      'Keep technical details private until we confirm a fix or agree on a disclosure date',
    ],
    contactLabel: 'Security report email',
    contactEmail: 'security@cuegroveapp.com',
    subject: 'Suggested subject: [Security] Short description',
    response: 'Target: acknowledge within 5 business days and complete initial triage within 10 business days.',
    safeHarborTitle: 'Good-faith research',
    safeHarborBody:
      'For good-faith security research that follows these boundaries, seeks to avoid harm, and is reported promptly, we will not pursue legal action based on that research alone. This statement does not authorize illegal activity, infringement of third-party rights, or service disruption.',
    limitsKicker: 'Honest limits',
    limitsTitle: 'Where the security work stands',
    limitsBody:
      'Administrator MFA and supply-chain checks are in place. The security update policy and release verification work are still underway and will be reflected here as they are completed. When we receive a security report, we confirm the issue, schedule the fix, and publish progress that can be verified.',
    repoTitle: 'Public repository and disclosure policy',
    repoBody: 'Review source code, build checks, supply-chain rules, and repository-level vulnerability reporting guidance.',
    repoAction: 'Open GitHub',
    homeFooter: 'Home',
    privacy: 'Privacy Promise',
    github: 'GitHub',
    copyrightLine: 'Calm, dependable tools that are secure by default',
  },
} as const;

export default function SecurityCommitmentPage() {
  const [locale, setLocale] = usePublicLocale();
  const t = securityCopy[locale];

  useEffect(() => {
    document.documentElement.lang = locale === 'zh' ? 'zh-CN' : 'en';
    document.title = locale === 'zh'
      ? '安全承诺 — CueGrove'
      : 'Security Commitment — CueGrove';
  }, [locale]);

  useEffect(() => {
    window.scrollTo({ top: 0 });
  }, []);

  return (
    <main className="privacy-promise-page security-commitment-page">
      <header className="site-header policy-header">
        <Link className="brand-lockup" to="/" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <nav className="policy-nav" aria-label={locale === 'zh' ? '安全页面导航' : 'Security page navigation'}>
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
          <span className="section-kicker"><ShieldCheck size={15} />{t.eyebrow}</span>
          <h1>{t.title}</h1>
          <p>{t.intro}</p>
          <div className="privacy-version">
            <span><ShieldCheck size={16} />{t.status}</span>
            <span>{t.effective}</span>
            <span className="security-disclosure-status"><Check size={15} />{t.disclosure}</span>
          </div>
        </div>
        <div className="security-hero-mark" aria-hidden="true">
          <div className="security-shield-orbit" />
          <ShieldCheck size={116} strokeWidth={1.25} />
          <span>SECURE<br />BY DESIGN</span>
        </div>
      </section>

      <section className="security-cisa-notice shell" aria-labelledby="cisa-notice-title">
        <CircleAlert size={22} />
        <div>
          <h2 id="cisa-notice-title">{t.noticeTitle}</h2>
          <p>{t.noticeBody}</p>
        </div>
        <a href="https://www.cisa.gov/securebydesign/pledge" target="_blank" rel="noreferrer">
          {t.noticeLink}<ExternalLink size={15} />
        </a>
      </section>

      <section className="privacy-principles shell" aria-labelledby="security-principles-title">
        <h2 className="visually-hidden" id="security-principles-title">{t.principlesLabel}</h2>
        <div className="privacy-principles-grid">
          {t.principles.map((principle) => (
            <article key={principle.title}>
              <h2>{principle.title}</h2>
              <p>{principle.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="privacy-boundary-section">
        <div className="shell">
          <div className="privacy-section-heading">
            <h2>{t.scopeTitle}</h2>
            <p>{t.scopeIntro}</p>
          </div>
          <div className="privacy-boundary-grid">
            <article className="privacy-boundary-card local">
              <span className="privacy-card-label"><Code2 size={16} />{t.appLabel}</span>
              <h3>{t.appTitle}</h3>
              <p>{t.appBody}</p>
              <ul>
                {t.appPoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
              </ul>
            </article>
            <article className="privacy-boundary-card website">
              <span className="privacy-card-label"><LockKeyhole size={16} />{t.serviceLabel}</span>
              <h3>{t.serviceTitle}</h3>
              <p>{t.serviceBody}</p>
              <ul>
                {t.servicePoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
              </ul>
            </article>
          </div>
        </div>
      </section>

      <section className="security-roadmap shell">
        <div className="privacy-section-heading">
          <h2>{t.roadmapTitle}</h2>
          <p>{t.roadmapIntro}</p>
        </div>
        <div className="security-roadmap-grid">
          {t.roadmap.map((item, index) => (
            <article key={item.title} className={item.state === '已完成' || item.state === 'Complete' ? 'complete' : ''}>
              <div className="security-roadmap-meta">
                <span>{String(index + 1).padStart(2, '0')}</span>
                <strong>{item.state}</strong>
              </div>
              <h3>{item.title}</h3>
              <p>{item.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="privacy-choice-section">
        <div className="shell security-report-grid">
          <div>
            <span className="section-kicker light"><Flag size={15} />{t.reportKicker}</span>
            <h2>{t.reportTitle}</h2>
            <p>{t.reportBody}</p>
            <ul>
              {t.reportPoints.map((point) => <li key={point}><Check size={15} />{point}</li>)}
            </ul>
          </div>
          <aside className="privacy-contact-card">
            <div className="privacy-card-icon"><Mail size={22} /></div>
            <span>{t.contactLabel}</span>
            <a href={`mailto:${t.contactEmail}?subject=${encodeURIComponent('[Security] ')}`}>{t.contactEmail}</a>
            <p>{t.subject}</p>
            <p>{t.response}</p>
          </aside>
        </div>
      </section>

      <section className="security-closing shell">
        <article className="security-safe-harbor">
          <ShieldCheck size={25} />
          <div>
            <h2>{t.safeHarborTitle}</h2>
            <p>{t.safeHarborBody}</p>
          </div>
        </article>
        <article className="security-limit-card">
          <h2>{t.limitsTitle}</h2>
          <p>{t.limitsBody}</p>
        </article>
        <article className="security-repo-card">
          <Code2 size={28} />
          <div>
            <h3>{t.repoTitle}</h3>
            <p>{t.repoBody}</p>
          </div>
          <a href="https://github.com/13304930782/PromptDock/blob/codex/cuegrove-site/SECURITY.md" target="_blank" rel="noreferrer">
            {t.repoAction}<ExternalLink size={15} />
          </a>
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
          <Link to="/privacy-promise">{t.privacy}</Link>
          <a href="https://github.com/13304930782/PromptDock" target="_blank" rel="noreferrer">{t.github}</a>
          <span>© {new Date().getFullYear()} CueGrove</span>
        </div>
      </footer>
    </main>
  );
}
