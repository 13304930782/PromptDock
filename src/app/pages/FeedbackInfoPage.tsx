import { ArrowRight, MessageSquare } from 'lucide-react';
import { Link } from 'react-router-dom';
import { usePublicLocale } from '../lib/locale';

export default function FeedbackInfoPage() {
  const [locale] = usePublicLocale();
  const zh = locale === 'zh';

  return (
    <main className="feedback-page shell">
      <div className="eyebrow"><MessageSquare size={15} /> PromptDock Early Access</div>
      <h1>{zh ? '告诉我们你的真实体验' : 'Tell us what you found'}</h1>
      <div className="feedback-card feedback-info-card">
        <p>{zh ? '已经加入 PromptDock Early Access？请打开我们发给你的通过邮件，点击其中的“提交反馈”按钮。每位测试用户都有独立的安全反馈入口。' : 'Already part of PromptDock Early Access? Open your approval email and click the “Send feedback” button. Each tester receives a private feedback link.'}</p>
        <p>{zh ? '如果没有找到邮件，请检查垃圾邮件文件夹。反馈入口不会公开展示，也不需要你提交私人提示词。' : 'If you cannot find the email, check your spam folder. The feedback form is not public and never asks you to share private prompts.'}</p>
        <div className="feedback-info-actions">
          <Link className="button button-primary" to="/#early-access">{zh ? '申请 Early Access' : 'Apply for Early Access'} <ArrowRight size={18} /></Link>
          <Link className="text-link" to="/">{zh ? '返回 CueGrove' : 'Back to CueGrove'}</Link>
        </div>
      </div>
    </main>
  );
}
