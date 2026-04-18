export const translations = {
  tr: {
    'nav.home': 'Ana Sayfa',
    'nav.services': 'Hizmetler',
    'nav.about': 'Hakkımızda',
    'nav.contact': 'İletişim',
    'hero.title': 'Geleceği İnşa Ediyoruz',
    'hero.sub': 'Harezm Ekosistemi ile kurumsal yazılım, yapay zeka ve finansal teknolojiler tek çatı altında.',
    'footer.copy': '© 2026 Harezm Ekosistemi. Tüm hakları saklıdır.',
  },
  en: {
    'nav.home': 'Home',
    'nav.services': 'Services',
    'nav.about': 'About',
    'nav.contact': 'Contact',
    'hero.title': 'Building the Future',
    'hero.sub': 'Corporate software, AI, and financial technologies under one ecosystem: Harezm.',
    'footer.copy': '© 2026 Harezm Ecosystem. All rights reserved.',
  },
} as const;

export type Lang = keyof typeof translations;
export type TranslationKey = keyof typeof translations['tr'];
