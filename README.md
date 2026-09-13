# e-any.online

e-any.online ekosisteminin kaynak kodu. İki parça:

## portal/
`e-any.online` statik landing sayfası — tek `index.html`, nginx container'ı ile serve edilir.
Canlı: https://e-any.online

## panel/
Elixir/Phoenix + LiveView panel — bookmark, şifre (Cloak AES-256-GCM), şifreli not, araç yönetimi.
Canlı: https://panel.e-any.online

**Geliştirme:** `cd panel && mix deps.get && mix test` (25 test). Deploy: `docker compose up -d --build`.