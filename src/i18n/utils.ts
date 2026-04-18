import { translations } from './translations';
import type { Lang, TranslationKey } from './translations';

export function getLangFromUrl(url: URL): Lang {
  const [, lang] = url.pathname.split('/');
  if (lang === 'en') return 'en';
  return 'tr';
}

export function t(key: TranslationKey, lang: Lang): string {
  return translations[lang][key] || translations['tr'][key] || key;
}

export function getLocalePath(path: string, lang: Lang): string {
  if (lang === 'tr') return path;
  
  const pathMap: Record<string, string> = {
    '/': '/en/',
    '/hizmetler': '/en/services',
    '/hakkimizda': '/en/about',
    '/iletisim': '/en/contact',
  };
  
  return pathMap[path] || `/en${path}`;
}

export function getAlternateLangPath(currentPath: string, currentLang: Lang): string {
  if (currentLang === 'tr') {
    return getLocalePath(currentPath, 'en');
  } else {
    // EN → TR (Simple reverse look-up or pattern replace)
    const reverseMap: Record<string, string> = {
      '/en/': '/',
      '/en/services': '/hizmetler',
      '/en/about': '/hakkimizda',
      '/en/contact': '/iletisim',
    };
    return reverseMap[currentPath] || currentPath.replace('/en', '') || '/';
  }
}
