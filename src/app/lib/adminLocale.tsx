import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import type { Locale } from '../content';

const STORAGE_KEY = 'cuegrove-admin-locale';

type AdminLocaleValue = {
  locale: Locale;
  setLocale: (locale: Locale) => void;
};

const AdminLocaleContext = createContext<AdminLocaleValue | null>(null);

export function AdminLocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(() => {
    const saved = window.sessionStorage.getItem(STORAGE_KEY);
    return saved === 'en' ? 'en' : 'zh';
  });

  const value = useMemo(() => ({
    locale,
    setLocale(next: Locale) {
      window.sessionStorage.setItem(STORAGE_KEY, next);
      setLocaleState(next);
    },
  }), [locale]);

  return <AdminLocaleContext.Provider value={value}>{children}</AdminLocaleContext.Provider>;
}

export function useAdminLocale() {
  const value = useContext(AdminLocaleContext);
  if (!value) throw new Error('useAdminLocale must be used inside AdminLocaleProvider');
  return value;
}
