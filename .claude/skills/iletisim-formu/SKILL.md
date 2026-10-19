---
name: iletisim-formu
description: Statik siteye kendi domain'inden e-posta gönderen bir iletişim formu ekler - Cloudflare Worker (sunucusuz), Turnstile (robot koruması) ve Resend (e-posta), hepsi ücretsiz katmanda; Worker GitHub Actions ile yayınlanır. "iletişim formu", "form", "bize yaz", "mesaj gönder", "resend", "turnstile", "e-posta gönder" geçtiğinde kullan.
---

# İletişim formu: Worker + Turnstile + Resend

```
Ziyaretçi ─form→ Cloudflare Worker ─doğrula→ Turnstile
                        └──────────gönder→ Resend ─→ senin e-postan
```

| Parça | Ücretsiz | Neden burada |
|---|---|---|
| Cloudflare Worker | Günde 100.000 istek | API anahtarı tarayıcıya giremez; bir sunucusuz fonksiyon gerekir |
| Turnstile | Sınırsız doğrulama | Robot koruması, CAPTCHA'sız; token'ı Worker doğrular |
| Resend | Günde 100, ayda 3.000 e-posta | Kendi domain'inden e-posta |

**Ön koşul: kendi domain'in.** Resend domain doğrulanmadan sadece hesap sahibinin adresine gönderir. Domain yoksa önce `alan-adi`. Ayrıca bir Cloudflare hesabı (domain'in DNS'i zaten orada) ve bir Resend hesabı.

Bu skill'in `templates/` klasöründen kopyala:
- `worker/` → repoda `worker/`
- `worker.yml` → `.github/workflows/worker.yml`
- `form.html` → sitenin iletişim sayfasına (Astro, Hugo, düz HTML; içeriği aynı)

## 1. Resend: domain ve anahtar

Resend hesabını kullanıcı açar. API anahtarını kullanıcı oluşturur (Resend › API Keys › **Sending access**, sadece bu domain) ve değerini sana göstermez. Domain'i ve DNS kayıtlarını API ile al; Türkiye'ye en yakın bölge `eu-west-1`:

```bash
# RESEND_API_KEY kullanıcının terminalinde tanımlı olmalı; değerini yazdırma.
curl -s -X POST https://api.resend.com/domains \
  -H "Authorization: Bearer $RESEND_API_KEY" -H "Content-Type: application/json" \
  -d '{"name":"send.<alanadi.com>","region":"eu-west-1"}' | jq '{id, records}'
```

Alt alan (`send.`) önerilir: ana domain'in e-posta itibarını korur. Dönen `records` listesindeki her kaydı (bir DKIM TXT, bir MX, bir SPF TXT) `type`, `name` ve `value` alanlarıyla **aynen** Cloudflare DNS'e ekle (`alan-adi` › DNS kaydı ekleme); `name` alt alana göre `resend._domainkey.send` gibi gelir. Hepsi **DNS only** (gri bulut). Sonra:

```bash
curl -s -X POST "https://api.resend.com/domains/<id>/verify" -H "Authorization: Bearer $RESEND_API_KEY"
curl -s "https://api.resend.com/domains/<id>" -H "Authorization: Bearer $RESEND_API_KEY" | jq -r .status
```

`verified` olana kadar birkaç dakika bekle. Kullanıcı Resend panelinden de "Verify" diyebilir.

## 2. Turnstile: site anahtarı

Kullanıcı Cloudflare panelinde **Turnstile › Add widget**: alan adları olarak domain'i ve (varsa) diğer yayın adreslerini ekler, mod "Managed". İki değer çıkar:
- **Site key**: gizli değil, `form.html`'deki `data-sitekey`.
- **Secret key**: Worker'ın sırrı, adım 3.

## 3. Worker

`worker/wrangler.toml`'da:
- `ALLOWED_ORIGINS`: sitenin yayında olduğu her adres (domain, `www`, Netlify, CloudFront, Cloudflare Pages), virgülle. Listede olmayan adresten gelen istek 403 alır.
- `MAIL_FROM`: `Site <form@send.alanadi.com>` (Resend'de doğrulanan alan).
- `MAIL_TO`: mesajların gideceği kutu.

Sırları kullanıcı kendi terminalinde girer (değerleri sohbete yapıştırmaz):

```bash
cd worker
npx -y wrangler@4 secret put RESEND_API_KEY
npx -y wrangler@4 secret put TURNSTILE_SECRET_KEY
```

İlk yayın lokalde: `npx -y wrangler@4 deploy`. Çıktıdaki `https://iletisim-formu.<hesap>.workers.dev` adresi `form.html`'deki `action` olur. Sonraki değişiklikleri `worker.yml` yayınlar; GitHub'da `CLOUDFLARE_API_TOKEN` (izin: **Account › Workers Scripts › Edit**) ve `CLOUDFLARE_ACCOUNT_ID` gerekir (`cloudflare-pages` › GitHub'a bağla; aynı token'a iki izin de verilebilir).

## 4. Lokal test (hesap gerekmez)

Cloudflare'in resmî Turnstile test anahtarlarıyla Worker'ı lokalde dene. `worker/.dev.vars` (git'e girmez):

```
TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA
RESEND_API_KEY=re_sahte_anahtar
```

```bash
npx -y wrangler@4 dev --port 8787 &
curl -s -X POST http://127.0.0.1:8787/ -H 'Origin: http://localhost:4321' \
  -F isim=Test -F mesaj=deneme -F cf-turnstile-response=XXXX.DUMMY.TOKEN.XXXX
```

Beklenen: `{"hata":"E-posta gönderilemedi"}` ve Worker logunda `Resend hatası 401`. Yani istek Turnstile'dan geçip Resend'e ulaştı; sahte anahtar reddedildi. Ayrıca: köken listede yoksa 403, alan eksik ya da uzunsa 400, token yoksa 400. Formun kendisini lokalde denerken site anahtarı olarak test anahtarı `1x00000000000000000000AA` kullanılır.

`.gitignore`'a `.dev.vars` ekle.

## 5. Canlı doğrula

Sitedeki formdan bir mesaj gönder; `MAIL_TO` kutusuna "Siteden mesaj: …" konulu e-posta gelmeli, "Yanıtla" ziyaretçinin adresine gitmeli. Gelmezse:

```bash
cd worker && npx -y wrangler@4 tail      # canlı log
```

| Log / cevap | Sebep |
|---|---|
| 403 "Bu adresten gönderilemez" | Sitenin adresi `ALLOWED_ORIGINS`'te yok |
| 400 "Robot doğrulaması başarısız" | Turnstile widget'ında bu alan adı ekli değil ya da sır yanlış |
| `Resend hatası 403` | Domain doğrulanmadı ya da `MAIL_FROM` doğrulanan alanda değil |
| `Resend hatası 401` | API anahtarı yanlış ya da silinmiş |

## Kullanıcıya teslim

Formun adresi, Worker adresi, mesajların gideceği kutu, Resend ve Turnstile panellerinin linkleri, sırların nasıl yenileneceği (`wrangler secret put`).
