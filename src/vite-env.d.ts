/// <reference types="vite/client" />

type TurnstileRenderOptions = {
  sitekey: string;
  action: string;
  theme?: 'light' | 'dark' | 'auto';
  callback: (token: string) => void;
  'expired-callback'?: () => void;
  'error-callback'?: () => void;
};

interface Window {
  turnstile?: {
    render: (container: HTMLElement, options: TurnstileRenderOptions) => string;
    remove: (widgetId: string) => void;
  };
}
