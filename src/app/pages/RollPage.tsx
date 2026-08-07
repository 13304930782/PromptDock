import { useEffect, useState } from 'react';
import { ArrowLeft, Dice5, ListChecks, ShieldCheck, Shuffle } from 'lucide-react';
import { Link } from 'react-router-dom';
import { randomOrder, secureRandomInt } from '../lib/random';
import { usePublicLocale } from '../lib/locale';

type Mode = 'dice' | 'matching';
type Pair = [string, string];
type DiceRoll = [number, number];

const pipPositions: Record<number, number[]> = {
  1: [5],
  2: [1, 9],
  3: [1, 5, 9],
  4: [1, 3, 7, 9],
  5: [1, 3, 5, 7, 9],
  6: [1, 3, 4, 6, 7, 9],
};

const rollCopy = {
  zh: {
    languageName: 'EN',
    home: '返回首页',
    eyebrow: 'CueGrove Utilities',
    title: '简单、清楚的实用工具',
    intro: '两个传统六面骰，以及两列内容的随机一一配对。所有计算都在你的浏览器中完成。',
    diceTab: '两个六面骰',
    matchingTab: '随机配对',
    diceTitle: '掷两个六面骰',
    diceBody: '同时掷出两个传统六面骰，每个骰子的结果都是 1 到 6。',
    rollDice: '掷骰子',
    rollAgain: '再掷一次',
    result: '分别点数',
    waitingDice: '点击按钮同时掷出两个骰子',
    diceHistory: '最近结果',
    noHistory: '还没有掷骰记录',
    matchingTitle: '两列随机配对',
    matchingBody: '先分别手动随机左右两列，每点一次都会将整列完整随机排序；完成目标次数后，再基于排序结果随机生成最终配对。',
    leftTitle: '左侧内容',
    rightTitle: '右侧内容',
    leftPlaceholder: '每行一个项目\n例如：\n小林\n小周\n小陈',
    rightPlaceholder: '每行一个项目\n例如：\n任务 A\n任务 B\n任务 C',
    itemCount: (count: number) => `${count} 项`,
    emptyHint: '请填写左右两列内容',
    mismatchHint: (left: number, right: number) => `数量不一致：左侧 ${left} 项，右侧 ${right} 项`,
    readyHint: (count: number) => `两列随机排序已完成，可以生成 ${count} 组配对`,
    progressHint: '请先分别完成左右两列的随机排序',
    match: '生成最终随机匹配',
    rematch: '重新生成最终匹配',
    autoFill: '骰子点数自动填入随机次数',
    autoFillHint: '开启后，左骰填写左列，右骰填写右列',
    manualFillHint: '已关闭自动填充，可分别修改两列次数',
    leftShuffle: '左列随机次数',
    rightShuffle: '右列随机次数',
    shuffleLeft: '完整随机左列一次',
    shuffleRight: '完整随机右列一次',
    shuffleProgress: (done: number, target: number) => `已完成 ${done} / ${target} 次`,
    shuffleDone: '两列随机排序完成',
    diceValues: (left: number, right: number) => `本次骰子点数：${left} · ${right}`,
    matchResult: '最终随机匹配',
    localNote: '本地计算 · 不保存填写内容 · 不记录 IP',
    noticeTitle: '使用须知',
    noticeBody: '本工具仅用于娱乐、教学、桌游及日常随机选择，不提供投注、支付、奖金、赔率或结算功能。严禁用于赌博、欺诈及其他违法活动。使用者应自行遵守所在地法律法规；随机结果不构成财务、法律或其他专业依据。',
    footerLine: '安静、可靠、尊重隐私的个人工具',
    privacy: '隐私承诺',
    security: '安全承诺',
  },
  en: {
    languageName: '中文',
    home: 'Back home',
    eyebrow: 'CueGrove Utilities',
    title: 'Simple, useful random tools',
    intro: 'Two traditional six-sided dice and one-to-one random matching between two lists. Everything runs in your browser.',
    diceTab: 'Two dice',
    matchingTab: 'Random matching',
    diceTitle: 'Roll two six-sided dice',
    diceBody: 'Roll two traditional six-sided dice together. Each result is between 1 and 6.',
    rollDice: 'Roll dice',
    rollAgain: 'Roll again',
    result: 'Individual values',
    waitingDice: 'Press the button to roll both dice',
    diceHistory: 'Recent results',
    noHistory: 'No rolls yet',
    matchingTitle: 'Match two lists',
    matchingBody: 'Randomize the left and right lists manually first. Each click fully shuffles one list; after both targets are complete, create random final pairs from those results.',
    leftTitle: 'Left list',
    rightTitle: 'Right list',
    leftPlaceholder: 'One item per line\nFor example:\nAlex\nBlair\nCasey',
    rightPlaceholder: 'One item per line\nFor example:\nTask A\nTask B\nTask C',
    itemCount: (count: number) => `${count} item${count === 1 ? '' : 's'}`,
    emptyHint: 'Enter items in both lists',
    mismatchHint: (left: number, right: number) => `Counts differ: ${left} on the left and ${right} on the right`,
    readyHint: (count: number) => `Both lists are ready. Create ${count} final pair${count === 1 ? '' : 's'}`,
    progressHint: 'Complete the full manual shuffles for both lists first',
    match: 'Create final random pairs',
    rematch: 'Create final pairs again',
    autoFill: 'Auto-fill shuffle counts from dice',
    autoFillHint: 'When enabled, the left and right dice fill their respective counts',
    manualFillHint: 'Auto-fill is off. You can edit each count separately',
    leftShuffle: 'Left shuffle count',
    rightShuffle: 'Right shuffle count',
    shuffleLeft: 'Fully shuffle left once',
    shuffleRight: 'Fully shuffle right once',
    shuffleProgress: (done: number, target: number) => `${done} / ${target} completed`,
    shuffleDone: 'Both lists are fully shuffled',
    diceValues: (left: number, right: number) => `Latest dice values: ${left} · ${right}`,
    matchResult: 'Final random pairs',
    localNote: 'Calculated locally · Entries are not stored · No IP logging',
    noticeTitle: 'Acceptable use',
    noticeBody: 'This tool is intended only for entertainment, education, tabletop games, and everyday random choices. It does not provide betting, payments, prizes, odds, or settlement. Gambling, fraud, and any other unlawful use are prohibited. You are responsible for following local laws, and results are not financial, legal, or other professional advice.',
    footerLine: 'Calm, dependable tools that respect your privacy',
    privacy: 'Privacy Promise',
    security: 'Security Commitment',
  },
} as const;

function itemsFrom(value: string) {
  return value.split(/\r?\n/).map((item) => item.trim()).filter(Boolean);
}

function DieFace({ value, small = false }: { value: number; small?: boolean }) {
  return (
    <span className={`die-face${small ? ' small' : ''}`} aria-label={String(value)}>
      {Array.from({ length: 9 }, (_, index) => (
        <i key={index} className={pipPositions[value].includes(index + 1) ? 'visible' : ''} />
      ))}
    </span>
  );
}

export default function RollPage() {
  const [locale, setLocale] = usePublicLocale();
  const [mode, setMode] = useState<Mode>('dice');
  const [diceResult, setDiceResult] = useState<DiceRoll | null>(null);
  const [diceHistory, setDiceHistory] = useState<DiceRoll[]>([]);
  const [leftInput, setLeftInput] = useState('');
  const [rightInput, setRightInput] = useState('');
  const [pairs, setPairs] = useState<Pair[]>([]);
  const [autoFillPasses, setAutoFillPasses] = useState(true);
  const [shufflePasses, setShufflePasses] = useState<DiceRoll>([1, 1]);
  const [shuffleClicks, setShuffleClicks] = useState<DiceRoll>([0, 0]);
  const t = rollCopy[locale];
  const leftItems = itemsFrom(leftInput);
  const rightItems = itemsFrom(rightInput);
  const countsMatch = leftItems.length > 0 && leftItems.length === rightItems.length;
  const shufflesComplete = countsMatch && shuffleClicks.every((count, index) => count >= shufflePasses[index]);

  useEffect(() => {
    document.documentElement.lang = locale === 'zh' ? 'zh-CN' : 'en';
    document.title = locale === 'zh' ? '实用工具 — CueGrove' : 'Utilities — CueGrove';
    window.scrollTo({ top: 0 });
  }, [locale]);

  const rollDice = () => {
    const result: DiceRoll = [secureRandomInt(6) + 1, secureRandomInt(6) + 1];
    setDiceResult(result);
    setDiceHistory((history) => [result, ...history].slice(0, 8));
    if (autoFillPasses) {
      setShufflePasses(result);
      setShuffleClicks([0, 0]);
      setPairs([]);
    }
    return result;
  };

  const matchLists = () => {
    if (!shufflesComplete) return;
    const matchedRight = randomOrder(rightItems);
    setPairs(leftItems.map<Pair>((item, index) => [item, matchedRight[index]]));
  };

  const updateList = (side: 'left' | 'right', value: string) => {
    if (side === 'left') setLeftInput(value);
    else setRightInput(value);
    setShuffleClicks((current) => side === 'left' ? [0, current[1]] : [current[0], 0]);
    setPairs([]);
  };

  const toggleAutoFill = (checked: boolean) => {
    setAutoFillPasses(checked);
    if (checked && diceResult) {
      setShufflePasses(diceResult);
      setShuffleClicks([0, 0]);
      setPairs([]);
    }
  };

  const updateShufflePass = (side: 0 | 1, value: string) => {
    const nextValue = Math.min(6, Math.max(1, Math.trunc(Number(value)) || 1));
    setShufflePasses((current) => side === 0 ? [nextValue, current[1]] : [current[0], nextValue]);
    setShuffleClicks((current) => side === 0 ? [0, current[1]] : [current[0], 0]);
    setPairs([]);
  };

  const shuffleListOnce = (side: 0 | 1) => {
    if (!countsMatch || shuffleClicks[side] >= shufflePasses[side]) return;
    if (side === 0) setLeftInput(randomOrder(leftItems).join('\n'));
    else setRightInput(randomOrder(rightItems).join('\n'));
    setShuffleClicks((current) => side === 0 ? [current[0] + 1, current[1]] : [current[0], current[1] + 1]);
    setPairs([]);
  };

  const matchHint = !leftItems.length && !rightItems.length
    ? t.emptyHint
    : countsMatch
      ? shufflesComplete ? t.readyHint(leftItems.length) : t.progressHint
      : t.mismatchHint(leftItems.length, rightItems.length);

  return (
    <main className="roll-page">
      <header className="site-header policy-header roll-header">
        <Link className="brand-lockup" to="/" aria-label="CueGrove home">
          <img src="/cuegrove-logo.png" alt="" />
          <span>CueGrove</span>
        </Link>
        <nav className="policy-nav" aria-label={locale === 'zh' ? '实用工具页面导航' : 'Utilities navigation'}>
          <Link className="policy-home-link" to="/"><ArrowLeft size={16} />{t.home}</Link>
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

      <section className="roll-tool shell" aria-label={locale === 'zh' ? '实用工具' : 'Utilities'}>
        <div className="roll-tabs" role="tablist" aria-label={locale === 'zh' ? '工具类型' : 'Utility type'}>
          <button type="button" role="tab" aria-selected={mode === 'dice'} className={mode === 'dice' ? 'active' : ''} onClick={() => setMode('dice')}>
            <Dice5 size={19} />{t.diceTab}
          </button>
          <button type="button" role="tab" aria-selected={mode === 'matching'} className={mode === 'matching' ? 'active' : ''} onClick={() => setMode('matching')}>
            <ListChecks size={19} />{t.matchingTab}
          </button>
        </div>

        {mode === 'dice' ? (
          <div className="dice-layout" role="tabpanel">
            <div className="roll-control-card">
              <div className="roll-section-heading">
                <h2>{t.diceTitle}</h2>
                <p>{t.diceBody}</p>
              </div>
              <button type="button" className="roll-primary" onClick={rollDice}>
                <Dice5 size={20} />{diceResult ? t.rollAgain : t.rollDice}
              </button>
            </div>

            <div className="dice-result-panel" aria-live="polite">
              {diceResult ? (
                <div className="die-result" key={`${diceResult.join('-')}-${diceHistory.length}`}>
                  <div className="die-pair">
                    <DieFace value={diceResult[0]} />
                    <DieFace value={diceResult[1]} />
                  </div>
                  <div className="die-points"><span>{t.result}</span><strong>{diceResult.join(' · ')}</strong></div>
                </div>
              ) : (
                <div className="roll-empty-state"><Dice5 size={38} /><p>{t.waitingDice}</p></div>
              )}
            </div>

            <aside className="dice-history-card">
              <h3>{t.diceHistory}</h3>
              {diceHistory.length ? (
                <ol>{diceHistory.map((roll, index) => (
                  <li key={`${index}-${roll.join('-')}`}>
                    <span className="history-dice-pair"><DieFace value={roll[0]} small /><DieFace value={roll[1]} small /></span>
                    <strong>{roll.join(' · ')}</strong>
                  </li>
                ))}</ol>
              ) : <p>{t.noHistory}</p>}
            </aside>
          </div>
        ) : (
          <div className="matching-panel" role="tabpanel">
            <div className="roll-section-heading matching-heading">
              <h2>{t.matchingTitle}</h2>
              <p>{t.matchingBody}</p>
            </div>

            <div className="matching-inputs">
              <label>
                <span><strong>{t.leftTitle}</strong><small>{t.itemCount(leftItems.length)}</small></span>
                <textarea rows={10} maxLength={5000} value={leftInput} placeholder={t.leftPlaceholder} onChange={(event) => updateList('left', event.target.value)} />
              </label>
              <div className="matching-divider" aria-hidden="true"><Shuffle size={20} /></div>
              <label>
                <span><strong>{t.rightTitle}</strong><small>{t.itemCount(rightItems.length)}</small></span>
                <textarea rows={10} maxLength={5000} value={rightInput} placeholder={t.rightPlaceholder} onChange={(event) => updateList('right', event.target.value)} />
              </label>
            </div>

            <div className="matching-controls">
              <div className="matching-controls-head">
                <label className="matching-switch">
                  <input type="checkbox" checked={autoFillPasses} onChange={(event) => toggleAutoFill(event.target.checked)} />
                  <span className="matching-switch-track" aria-hidden="true"><i /></span>
                  <span><strong>{t.autoFill}</strong><small>{autoFillPasses ? t.autoFillHint : t.manualFillHint}</small></span>
                </label>
                <button type="button" className="matching-roll-button" onClick={rollDice}>
                  <Dice5 size={18} />{diceResult ? t.rollAgain : t.rollDice}
                </button>
              </div>

              <div className="shuffle-pass-controls">
                <div className="shuffle-pass-card">
                  <label htmlFor="left-shuffle-count">{t.leftShuffle}</label>
                  <input id="left-shuffle-count" type="number" min="1" max="6" step="1" inputMode="numeric" value={shufflePasses[0]} disabled={autoFillPasses} onChange={(event) => updateShufflePass(0, event.target.value)} />
                  <button type="button" className="matching-shuffle-button" onClick={() => shuffleListOnce(0)} disabled={!countsMatch || shuffleClicks[0] >= shufflePasses[0]}>
                    <Shuffle size={16} /><span>{t.shuffleLeft}<small>{t.shuffleProgress(shuffleClicks[0], shufflePasses[0])}</small></span>
                  </button>
                </div>
                <div className="shuffle-pass-card">
                  <label htmlFor="right-shuffle-count">{t.rightShuffle}</label>
                  <input id="right-shuffle-count" type="number" min="1" max="6" step="1" inputMode="numeric" value={shufflePasses[1]} disabled={autoFillPasses} onChange={(event) => updateShufflePass(1, event.target.value)} />
                  <button type="button" className="matching-shuffle-button" onClick={() => shuffleListOnce(1)} disabled={!countsMatch || shuffleClicks[1] >= shufflePasses[1]}>
                    <Shuffle size={16} /><span>{t.shuffleRight}<small>{t.shuffleProgress(shuffleClicks[1], shufflePasses[1])}</small></span>
                  </button>
                </div>
                {diceResult && (
                  <div className="matching-dice-values" aria-live="polite">
                    <span><DieFace value={diceResult[0]} small /><DieFace value={diceResult[1]} small /></span>
                    <strong>{t.diceValues(diceResult[0], diceResult[1])}</strong>
                  </div>
                )}
              </div>
            </div>

            <div className="matching-meta">
              <div className={`matching-status${shufflesComplete ? ' ready' : ''}`} role="status">{matchHint}</div>
              <strong>{shufflesComplete ? t.shuffleDone : `${shuffleClicks[0]} / ${shufflePasses[0]} · ${shuffleClicks[1]} / ${shufflePasses[1]}`}</strong>
            </div>
            <button type="button" className="roll-primary matching-button" onClick={matchLists} disabled={!shufflesComplete}>
              <Shuffle size={19} />{pairs.length ? t.rematch : t.match}
            </button>

            {pairs.length > 0 && (
              <section className="matching-results" aria-labelledby="matching-results-title" aria-live="polite">
                <h3 id="matching-results-title">{t.matchResult}</h3>
                <div className="matching-results-head" aria-hidden="true">
                  <span>#</span><strong>{t.leftTitle}</strong><strong>{t.rightTitle}</strong>
                </div>
                <ol>
                  {pairs.map(([left, right], index) => (
                    <li key={`${index}-${left}-${right}`}>
                      <small>{index + 1}</small>
                      <span>{left}</span>
                      <span>{right}</span>
                    </li>
                  ))}
                </ol>
              </section>
            )}
          </div>
        )}
      </section>

      <section className="roll-notice shell" aria-labelledby="roll-notice-title">
        <ShieldCheck size={24} />
        <div><h2 id="roll-notice-title">{t.noticeTitle}</h2><p>{t.noticeBody}</p></div>
      </section>

      <footer className="site-footer shell">
        <div className="footer-brand">
          <div className="brand-lockup"><img src="/cuegrove-logo.png" alt="" /><span>CueGrove</span></div>
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
