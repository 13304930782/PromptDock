import { useCallback, useEffect, useState, type Dispatch, type SetStateAction } from 'react';
import type { Locale } from '../content';

const SESSION_LOCALE_KEY = 'cuegrove-session-locale';
const LEGACY_LOCALE_KEY = 'cuegrove-locale';

export function systemLocale(): Locale {
  const preferredLanguage = navigator.languages?.[0] || navigator.language || 'en';
  return preferredLanguage.toLowerCase().startsWith('zh') ? 'zh' : 'en';
}

function storedSessionLocale(): Locale | null {
  const saved = window.sessionStorage.getItem(SESSION_LOCALE_KEY);
  return saved === 'zh' || saved === 'en' ? saved : null;
}

export function usePublicLocale(): [Locale, Dispatch<SetStateAction<Locale>>] {
  const [locale, setLocaleState] = useState<Locale>(() => storedSessionLocale() || systemLocale());

  useEffect(() => {
    // Earlier versions persisted the choice indefinitely. Removing that value
    // lets every new browsing session begin from the operating-system language.
    window.localStorage.removeItem(LEGACY_LOCALE_KEY);

    const followSystemLanguage = () => {
      if (!storedSessionLocale()) setLocaleState(systemLocale());
    };
    window.addEventListener('languagechange', followSystemLanguage);
    return () => window.removeEventListener('languagechange', followSystemLanguage);
  }, []);

  const setLocale = useCallback<Dispatch<SetStateAction<Locale>>>((nextValue) => {
    setLocaleState((current) => {
      const next = typeof nextValue === 'function' ? nextValue(current) : nextValue;
      window.sessionStorage.setItem(SESSION_LOCALE_KEY, next);
      return next;
    });
  }, []);

  return [locale, setLocale];
}
