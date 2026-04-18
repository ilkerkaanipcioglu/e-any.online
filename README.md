# Harezm Ekosistemi Astro Template

Bu template, Harezm ekosistemine dahil olacak yeni web siteleri için standartlaştırılmış bir temel sunar.

## Özellikler

- **Astro v5 + Tailwind v4**: En güncel performans ve stil araçları.
- **Brand System**: CSS değişkenleri (`--primary`, `--accent`) ve `data-brand` attribute'u ile tek bir değişiklikle Eny, AgentAndBot veya Harezm moduna geçiş yapabilirsiniz.
- **i18n Ready**: TR ve EN dilleri için path-based routing altyapısı hazırdır.
- **Premium Design**: Syne fontu, Glassmorphism, ve Motion animasyonları ile modern bir görünüm.
- **Dark/Light Mode**: LocalStorage tabanlı, sistem tercihlerine duyarlı tema desteği.

## Kurulum

1. Bağımlılıkları yükleyin:
   ```bash
   npm install
   ```

2. Geliştirme sunucusunu başlatın:
   ```bash
   npm run dev
   ```

## Marka Değiştirme

`src/layouts/Layout.astro` dosyasındaki veya sayfalardaki `brand` propunu değiştirerek farklı markaların tasarımına bürünebilirsiniz:

```astro
<Layout brand="eny"> ... </Layout>
```

Marka spesifik renkleri ve temel ayarları `src/styles/global.css` dosyasından düzenleyebilirsiniz.

## Çeviriler

Yeni çeviri anahtarlarını `src/i18n/translations.ts` dosyasına ekleyebilirsiniz.
