---
name: cloudflare-pages
description: Statik siteyi Cloudflare Pages'te ücretsiz yayınlar ve GitHub Actions'a bağlar - PR'da önizleme linki, main'e merge'de production. Netlify kredisi bittiğinde ya da kredi modeli istenmediğinde alternatif rota. "cloudflare", "pages", "pages.dev", "wrangler", "netlify kredisi bitti" geçtiğinde kullan.
---

# Cloudflare Pages + GitHub Actions

Netlify rotasının aynısı, Cloudflare'de: site Cloudflare'in küresel ağından verilir (İstanbul dahil), deploy'u GitHub Actions yapar. Netlify'ın ücretsiz planı kredi tabanlıdır (ayda 300 kredi, her production deploy 15 kredi); sık merge edilen bir sınıf projesinde bu çabuk biter. Cloudflare Pages'te böyle bir kredi yoktur.

Ön koşul: Cloudflare hesabı (ücretsiz), `gh` girişli, repo push edilmiş (`github-cicd`). Wrangler `npx` ile çalışır, kurulum gerekmez.

## 1. Proje (bir kere, kullanıcının bilgisayarında)

```bash
npx -y wrangler@4 login                                   # tarayıcı açar
npx -y wrangler@4 whoami                                  # Account ID burada
npx -y wrangler@4 pages project create <proje-adi> --production-branch main
```

Proje adı `<proje-adi>.pages.dev` adresi olur; küçük harf, rakam, tire. Ad başkasında varsa Cloudflare sona bir ek koyar: gerçek adres `npx -y wrangler@4 pages project list` çıktısında.

## 2. GitHub'a bağla

Bu skill'in `templates/cloudflare.yml` dosyasını `.github/workflows/cloudflare.yml` olarak kopyala. Build'li sitede `PUBLISH_DIR`'i build çıktısı yap (Astro/Vite: `dist`).

```bash
gh variable set CLOUDFLARE_ACCOUNT_ID --body "<account-id>"
gh variable set CF_PAGES_PROJECT --body "<proje-adi>"
```

API token'ı kullanıcının tek elle yaptığı adım; değerini görme. Sayfayı aç ve tek komut bırak:

```bash
open "https://dash.cloudflare.com/profile/api-tokens" 2>/dev/null \
  || xdg-open "https://dash.cloudflare.com/profile/api-tokens"
```

1. **Create Token › Create Custom Token** › izin: **Account › Cloudflare Pages › Edit** › Account Resources: kendi hesabı › bir son kullanma tarihi › Create › kopyala.
2. Terminalde `gh secret set CLOUDFLARE_API_TOKEN --repo <sahip>/<repo>`, istemde yapıştır.

Sonra `gh workflow run cloudflare.yml --ref main` ile bir çalışma başlat; "Ayarları kontrol et" adımı geçmeli. "secret'ı yok" hatası secret'ın boş kaydedildiğini gösterir.

## 3. Akış

- **PR:** `pr-<numara>` dalına deploy; PR'a "Cloudflare Pages önizleme: https://pr-<n>.<proje>.pages.dev" yorumu düşer.
- **main:** production; adres `https://<proje>.pages.dev`.

Doğrula:

```bash
curl -sI "https://<proje-adi>.pages.dev/" | head -1
```

## Netlify ile birlikte

Aynı repo hem Netlify'a hem Cloudflare'e yayınlayabilir; her rota kendi workflow'unu getirir ve PR yorumları birbirini ezmez. İletişim formu (`iletisim-formu`) bir Worker'a gönderdiği için her kopyada aynı çalışır; Pages adresini Worker'ın `ALLOWED_ORIGINS` listesine eklemek yeter.

## Alt sayfalar

Cloudflare Pages `/hakkinda` isteğinde `hakkinda.html` ya da `hakkinda/index.html` dosyasını kendisi bulur; S3'teki alt sayfa sorunu burada yoktur.

## Silme

```bash
npx -y wrangler@4 pages project delete <proje-adi>
```

Silmeden önce kullanıcıya proje adını göster ve onay al; tüm deploy'lar gider. Workflow dosyasını kaldıran bir PR aç ve token'ı Cloudflare panelinden iptal et.

## Ayrıntı

Workers, Turnstile, wrangler için resmî skill'ler: `npx skills add cloudflare/skills`.
