import { useEffect, useRef } from 'react';

const SITE_KEY = '0x4AAAAAAD-TSGaNmo2B-Hr0';
const ACTION = 'turnstile-spin-v2';

type Props = {
  onTokenChange: (token: string) => void;
};

export default function Turnstile({ onTokenChange }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const widgetIdRef = useRef<string | null>(null);
  const onTokenChangeRef = useRef(onTokenChange);

  useEffect(() => {
    onTokenChangeRef.current = onTokenChange;
  }, [onTokenChange]);

  useEffect(() => {
    const script = document.querySelector<HTMLScriptElement>('script[data-cuegrove-turnstile]');

    const renderWidget = () => {
      if (!containerRef.current || !window.turnstile || widgetIdRef.current) return;
      widgetIdRef.current = window.turnstile.render(containerRef.current, {
        sitekey: SITE_KEY,
        action: ACTION,
        theme: 'light',
        callback: (token) => onTokenChangeRef.current(token),
        'expired-callback': () => onTokenChangeRef.current(''),
        'error-callback': () => onTokenChangeRef.current(''),
      });
    };

    renderWidget();
    script?.addEventListener('load', renderWidget);

    return () => {
      script?.removeEventListener('load', renderWidget);
      if (widgetIdRef.current && window.turnstile) {
        window.turnstile.remove(widgetIdRef.current);
      }
      widgetIdRef.current = null;
    };
  }, []);

  return (
    <div
      ref={containerRef}
      className="cf-turnstile"
      data-sitekey={SITE_KEY}
      data-action={ACTION}
      aria-label="Cloudflare Turnstile human verification"
    />
  );
}
