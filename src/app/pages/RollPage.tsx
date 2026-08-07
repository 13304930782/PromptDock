import { useEffect, useState } from 'react';
import {
  ArrowLeft,
  Dice5,
  ListChecks,
  Plus,
  ShieldCheck,
  Shuffle,
  Trash2,
} from 'lucide-react';
import { Link } from 'react-router-dom';
import { secureRandomInt } from '../lib/random';
import { usePublicLocale } from '../lib/locale';

type Mode = 'dice' | 'forms';

type RandomForm = {
  id: number;
  name: string;
  items: string;
  result: string;
  rolls: number;
  history: string[];
};

const diceSides = [4, 6, 8, 10, 12, 20, 100];
const diceCounts = Array.from({ length: 10 }, (_, index) => index + 1);

const rollCopy = {
  zh: {
    languageName: 'EN',
    home: '返回首页',
    eyebrow: 'CueGrove Random',
    title: '简单、清楚的随机工具',
    intro: '只保留掷骰子与表单随机。所有计算都在你的浏览器中完成，不上传填写内容。',
    diceTab: '骰子',
    formsTab: '表单随机',
    diceTitle: '掷骰子',
    diceBody: '选择骰子数量与面数，然后生成一组随机点数。',
    diceCount: '骰子数量',
    diceSides: '骰子面数',
    rollDice: '掷骰子',
    rollAgain: '再掷一次',
    total: '总点数',
    waitingDice: '设置好骰子后，点击按钮开始。',
    diceHistory: '最近结果',
    noHistory: '还没有随机记录',
    formsTitle: '表单随机',
    formsBody: '每行填写一个选项。重复行会按出现次数增加被抽中的概率。',
    addForm: '添加表单',
    rollAll: '全部随机',
    formName: '表单名称',
    formNameFallback: '未命名表单',
    options: '随机选项',
    optionsPlaceholder: '每行一个选项\n例如：\n北京\n上海\n广州',
    optionCount: (count: number) => `${count} 个有效选项`,
    emptyOptions: '请先填写至少一个选项',
    rollForm: '随机这个表单',
    removeForm: '删除表单',
    currentResult: '当前结果',
    waitingForm: '等待随机',
    rollCount: (count: number) => `已随机 ${count} 次`,
    maxForms: '最多可同时使用 4 个表单。',
    noticeTitle: '使用须知',
    noticeBody: '本工具仅用于娱乐、教学、桌游及日常随机选择，不提供投注、支付、奖金、赔率或结算功能。严禁用于赌博、欺诈及其他违法活动。使用者应自行遵守所在地法律法规；随机结果不构成财务、法律或其他专业依据。',
    localNote: '本地计算 · 不保存填写内容 · 不记录 IP',
    footerLine: '安静、可靠、尊重隐私的个人工具',
    privacy: '隐私承诺',
    security: '安全承诺',
  },
  en: {
    languageName: '中文',
    home: 'Back home',
    eyebrow: 'CueGrove Random',
    title: 'Randomness, kept simple',
    intro: 'Just dice and form draws. Everything runs in your browser, and your entries are never uploaded.',
    diceTab: 'Dice',
    formsTab: 'Form draw',
    diceTitle: 'Roll dice',
    diceBody: 'Choose how many dice to roll and how many sides each die has.',
    diceCount: 'Number of dice',
    diceSides: 'Sides per die',
    rollDice: 'Roll dice',
    rollAgain: 'Roll again',
    total: 'Total',
    waitingDice: 'Choose your dice, then roll.',
    diceHistory: 'Recent results',
    noHistory: 'No results yet',
    formsTitle: 'Form draw',
    formsBody: 'Enter one option per line. Repeated lines receive proportionally more chances to be selected.',
    addForm: 'Add form',
    rollAll: 'Draw all',
    formName: 'Form name',
    formNameFallback: 'Untitled form',
    options: 'Options',
    optionsPlaceholder: 'One option per line\nFor example:\nBeijing\nShanghai\nGuangzhou',
    optionCount: (count: number) => `${count} valid option${count === 1 ? '' : 's'}`,
    emptyOptions: 'Add at least one option first',
    rollForm: 'Draw from this form',
    removeForm: 'Remove form',
    currentResult: 'Current result',
    waitingForm: 'Waiting for a draw',
    rollCount: (count: number) => `${count} draw${count === 1 ? '' : 's'}`,
    maxForms: 'You can use up to 4 forms at once.',
    noticeTitle: 'Acceptable use',
    noticeBody: 'This tool is intended only for entertainment, education, tabletop games, and everyday random choices. It does not provide betting, payments, prizes, odds, or settlement. Gambling, fraud, and any other unlawful use are prohibited. You are responsible for following local laws, and results are not financial, legal, or other professional advice.',
    localNote: 'Calculated locally · Entries are not stored · No IP logging',
    footerLine: 'Calm, dependable tools that respect your privacy',
    privacy: 'Privacy Promise',
    security: 'Security Commitment',
  },
} as const;

function createForm(id: number, locale: 'zh' | 'en'): RandomForm {
  return {
    id,
    name: locale === 'zh' ? `表单 ${id}` : `Form ${id}`,
    items: '',
    result: '',
    rolls: 0,
    history: [],
  };
}

function optionsFrom(items: string) {
  return items.split(/\r?\n/).map((item) => item.trim()).filter(Boolean);
}

export default function RollPage() {
  const [locale, setLocale] = usePublicLocale();
  const [mode, setMode] = useState<Mode>('dice');
  const [sides, setSides] = useState(6);
  const [diceCount, setDiceCount] = useState(2);
  const [diceResult, setDiceResult] = useState<number[]>([]);
  const [diceHistory, setDiceHistory] = useState<number[][]>([]);
  const [forms, setForms] = useState<RandomForm[]>(() => [createForm(1, locale), createForm(2, locale)]);
  const t = rollCopy[locale];

  useEffect(() => {
    document.documentElement.lang = locale === 'zh' ? 'zh-CN' : 'en';
    document.title = locale === 'zh' ? '随机工具 — CueGrove' : 'Random Tool — CueGrove';
    window.scrollTo({ top: 0 });
    setForms((current) => current.map((form) => {
      if (form.name !== `表单 ${form.id}` && form.name !== `Form ${form.id}`) return form;
      return { ...form, name: locale === 'zh' ? `表单 ${form.id}` : `Form ${form.id}` };
    }));
  }, [locale]);

  const rollDice = () => {
    const result = Array.from({ length: diceCount }, () => secureRandomInt(sides) + 1);
    setDiceResult(result);
    setDiceHistory((history) => [result, ...history].slice(0, 6));
  };

  const drawForm = (form: RandomForm) => {
    const options = optionsFrom(form.items);
    if (!options.length) return form;
    const result = options[secureRandomInt(options.length)];
    return {
      ...form,
      result,
      rolls: form.rolls + 1,
      history: [result, ...form.history].slice(0, 4),
    };
  };

  const updateForm = (id: number, change: Partial<RandomForm>) => {
    setForms((current) => current.map((form) => (form.id === id ? { ...form, ...change } : form)));
  };

  const rollForm = (id: number) => {
    setForms((current) => current.map((form) => (form.id === id ? drawForm(form) : form)));
  };

  const rollAllForms = () => setForms((current) => current.map(drawForm));

  const addForm = () => {
    setForms((current) => {
      if (current.length >= 4) return current;
      const id = Math.max(...current.map((form) => form.id)) + 1;
      return [...current, createForm(id, locale)];
    });
  };

  const removeForm = (id: number) => {
    setForms((current) => (current.length <= 1 ? current : current.filter((form) => form.id !== id)));
  };

  const diceTotal = diceResult.reduce((sum, value) => sum + value, 0);
  const hasFormOptions = forms.some((form) => optionsFrom(form.items).length > 0);

  return (
    <main className="roll-page">
      <header className="site-header policy-header roll-header">
        <Link className="brand-lockup" to="/" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <nav className="policy-nav" aria-label={locale === 'zh' ? '随机工具页面导航' : 'Random tool navigation'}>
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

      <section className="roll-intro shell">
        <span className="section-kicker"><ShieldCheck size={15} />{t.eyebrow}</span>
        <h1>{t.title}</h1>
        <p>{t.intro}</p>
        <div className="roll-local-note"><span />{t.localNote}</div>
      </section>

      <section className="roll-tool shell" aria-label={locale === 'zh' ? '随机工具' : 'Random tool'}>
        <div className="roll-tabs" role="tablist" aria-label={locale === 'zh' ? '随机方式' : 'Random mode'}>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'dice'}
            className={mode === 'dice' ? 'active' : ''}
            onClick={() => setMode('dice')}
          >
            <Dice5 size={19} />{t.diceTab}
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'forms'}
            className={mode === 'forms' ? 'active' : ''}
            onClick={() => setMode('forms')}
          >
            <ListChecks size={19} />{t.formsTab}
          </button>
        </div>

        {mode === 'dice' ? (
          <div className="dice-layout" role="tabpanel">
            <div className="roll-control-card">
              <div className="roll-section-heading">
                <h2>{t.diceTitle}</h2>
                <p>{t.diceBody}</p>
              </div>
              <div className="dice-controls">
                <label>
                  <span>{t.diceCount}</span>
                  <select value={diceCount} onChange={(event) => setDiceCount(Number(event.target.value))}>
                    {diceCounts.map((count) => <option key={count} value={count}>{count}</option>)}
                  </select>
                </label>
                <label>
                  <span>{t.diceSides}</span>
                  <select value={sides} onChange={(event) => setSides(Number(event.target.value))}>
                    {diceSides.map((side) => <option key={side} value={side}>D{side}</option>)}
                  </select>
                </label>
              </div>
              <button type="button" className="roll-primary" onClick={rollDice}>
                <Dice5 size={20} />{diceResult.length ? t.rollAgain : t.rollDice}
              </button>
            </div>

            <div className="dice-result-panel" aria-live="polite">
              {diceResult.length ? (
                <>
                  <div className="dice-total">
                    <span>{t.total}</span>
                    <strong key={`${diceTotal}-${diceHistory.length}`}>{diceTotal}</strong>
                  </div>
                  <div className="dice-values" aria-label={diceResult.join(', ')}>
                    {diceResult.map((value, index) => (
                      <span key={`${diceHistory.length}-${index}`}>{value}</span>
                    ))}
                  </div>
                </>
              ) : (
                <div className="roll-empty-state">
                  <Dice5 size={38} />
                  <p>{t.waitingDice}</p>
                </div>
              )}
            </div>

            <aside className="dice-history-card">
              <h3>{t.diceHistory}</h3>
              {diceHistory.length ? (
                <ol>
                  {diceHistory.map((result, index) => (
                    <li key={`${index}-${result.join('-')}`}>
                      <span>{result.join(' · ')}</span>
                      <strong>{result.reduce((sum, value) => sum + value, 0)}</strong>
                    </li>
                  ))}
                </ol>
              ) : <p>{t.noHistory}</p>}
            </aside>
          </div>
        ) : (
          <div className="forms-panel" role="tabpanel">
            <div className="forms-toolbar">
              <div className="roll-section-heading">
                <h2>{t.formsTitle}</h2>
                <p>{t.formsBody}</p>
              </div>
              <div className="forms-actions">
                <button type="button" className="roll-secondary" onClick={addForm} disabled={forms.length >= 4} title={forms.length >= 4 ? t.maxForms : undefined}>
                  <Plus size={18} />{t.addForm}
                </button>
                <button type="button" className="roll-primary" onClick={rollAllForms} disabled={!hasFormOptions}>
                  <Shuffle size={18} />{t.rollAll}
                </button>
              </div>
            </div>

            <div className="random-forms-grid">
              {forms.map((form) => {
                const optionCount = optionsFrom(form.items).length;
                return (
                  <article className="random-form-card" key={form.id}>
                    <div className="random-form-title-row">
                      <label>
                        <span className="visually-hidden">{t.formName}</span>
                        <input
                          value={form.name}
                          maxLength={32}
                          placeholder={t.formNameFallback}
                          onChange={(event) => updateForm(form.id, { name: event.target.value })}
                        />
                      </label>
                      <button
                        type="button"
                        className="icon-button"
                        onClick={() => removeForm(form.id)}
                        disabled={forms.length <= 1}
                        aria-label={t.removeForm}
                        title={t.removeForm}
                      >
                        <Trash2 size={17} />
                      </button>
                    </div>

                    <div className={`form-result${form.result ? ' has-result' : ''}`} aria-live="polite">
                      <span>{t.currentResult}</span>
                      <strong key={`${form.id}-${form.rolls}`}>{form.result || t.waitingForm}</strong>
                      <small>{t.rollCount(form.rolls)}</small>
                    </div>

                    <label className="random-options-field">
                      <span>{t.options}</span>
                      <textarea
                        rows={7}
                        maxLength={5000}
                        value={form.items}
                        placeholder={t.optionsPlaceholder}
                        onChange={(event) => updateForm(form.id, { items: event.target.value })}
                      />
                      <small className={optionCount ? '' : 'empty'}>{optionCount ? t.optionCount(optionCount) : t.emptyOptions}</small>
                    </label>

                    <button type="button" className="roll-form-button" onClick={() => rollForm(form.id)} disabled={!optionCount}>
                      <Shuffle size={17} />{t.rollForm}
                    </button>

                    {form.history.length > 1 && (
                      <div className="form-history" aria-label={t.diceHistory}>
                        {form.history.slice(1).map((item, index) => <span key={`${item}-${index}`}>{item}</span>)}
                      </div>
                    )}
                  </article>
                );
              })}
            </div>
            {forms.length >= 4 && <p className="max-forms-note">{t.maxForms}</p>}
          </div>
        )}
      </section>

      <section className="roll-notice shell" aria-labelledby="roll-notice-title">
        <ShieldCheck size={24} />
        <div>
          <h2 id="roll-notice-title">{t.noticeTitle}</h2>
          <p>{t.noticeBody}</p>
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
          <Link to="/privacy-promise">{t.privacy}</Link>
          <Link to="/security">{t.security}</Link>
          <span>© {new Date().getFullYear()} CueGrove</span>
        </div>
      </footer>
    </main>
  );
}
