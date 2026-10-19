---
name: alan-adi
description: Kendi domain'ini (ör. turkticaret.net'ten alınan .com) siteye bağlar - nameserver'ları ücretsiz Cloudflare DNS'e taşır, Netlify'a domain ve HTTPS bağlar, Resend ve diğer servisler için DNS kaydı ekler. "domain", "alan adı", "kendi adresim", "turkticaret", "nameserver", "DNS kaydı" geçtiğinde kullan.
---

# Kendi domain'in

Domain kayıt firmasından alınır (Türkiye'de turkticaret.net gibi), DNS'i ise **Cloudflare**'de yönetilir: ücretsizdir, API'si vardır, kök domain'de CNAME desteği vardır ve sonraki adımlarda (Turnstile, Worker, Pages) zaten Cloudflare kullanılır.

Bu, kurulumun tek ücretli kalemidir. Kullanıcıya söyle: ilk yıl fiyatı kampanyalı olabilir, **yenileme ücretine** sepette bakılmalı.

## 1. Satın alma (kullanıcı yapar)

Kayıt firmasında domain'i alır. Gerekmeyen ek hizmetleri (hosting, e-posta paketi, SSL) sepetten çıkarsın: hepsi bu kurulumda ücretsiz olarak var. Kişisel bilgilerin gizlenmesi (WHOIS gizliliği) ücretsizse açsın.

## 2. DNS'i Cloudflare'e taşı (kullanıcı yapar, bir kere)

1. Cloudflare paneli › **Domains › Onboard a domain** › kök domain (`alanadi.com`) › **Free** plan.
2. Cloudflare iki nameserver verir (ör. `ada.ns.cloudflare.com`). Bunlar hesaba özeldir; tam olarak kopyalanır.
3. Kayıt firmasının panelinde domain › **Nameserver / DNS sunucuları** › varsayılanları sil, Cloudflare'in ikisini yaz. DNSSEC açıksa önce kapat.
4. Aktif olması 24 saate kadar sürebilir; çoğu zaman bir saat içinde olur.

Kontrol:

```bash
dig +short NS alanadi.com      # Cloudflare'in iki nameserver'ı görünmeli
```

## 3. DNS kaydı ekleme

Panelden: Cloudflare › domain › **DNS › Records › Add record**. Bu kurulumdaki her kayıt **DNS only** (gri bulut) olmalı: Netlify ve Resend kendi sertifikalarını ve doğrulamalarını yapar, Cloudflare'in proxy'si araya girerse bozulur.

API ile (token izni: **Zone › DNS › Edit**, sadece bu domain):

```bash
ZONE=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=alanadi.com" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" | jq -r '.result[0].id')
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_DNS_TOKEN" -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"www","content":"<site>.netlify.app","proxied":false}' | jq '.success'
```

Token değerini kullanıcı kendi terminalinde ortam değişkeni olarak tanımlar; yazdırma.

## 4. Netlify'a bağla

| Kayıt | Ad | Değer |
|---|---|---|
| CNAME | `@` (kök) | `apex-loadbalancer.netlify.com` |
| CNAME | `www` | `<site>.netlify.app` |

Kök domain'de CNAME standart DNS'te olmaz; Cloudflare bunu kendisi düzleştirir. Başka bir DNS sağlayıcısında kalınırsa kök için `A 75.2.60.5` kullanılır.

```bash
netlify api updateSite --data '{"site_id":"<site-id>","body":{"custom_domain":"alanadi.com"}}' | jq '.custom_domain'
```

Netlify DNS kaydını görünce Let's Encrypt sertifikasını kendisi alır; birkaç dakika ile birkaç saat sürebilir. Kontrol:

```bash
curl -sI https://alanadi.com | head -1
curl -sI https://www.alanadi.com | grep -i location     # kök domain'e yönlenmeli
```

## 5. E-posta gönderme (Resend)

`iletisim-formu` › Resend adımının döndürdüğü kayıtlar buraya, adım 3'teki gibi eklenir. Gelen e-posta (alanadi.com'a mail almak) bu kurulumun parçası değil; Cloudflare Email Routing ile ücretsiz olarak kişisel bir kutuya yönlendirilebilir.

## CloudFront rotaları

S3 ve EC2 rotaları `*.cloudfront.net` adresinde kalır. Onlara da domain bağlamak için `us-east-1`'de bir ACM sertifikası ve Terraform değişikliği gerekir (`aws-statik-site` › Özel domain). Genelde domain tek bir rotaya (Netlify ya da Cloudflare Pages) bağlanır, diğerleri yedek adres olarak kalır.

## Kullanıcıya teslim

Domain, HTTPS'in çalıştığı (`curl -sI` çıktısı), Cloudflare'deki kayıtların listesi, yenileme tarihi hatırlatması.
