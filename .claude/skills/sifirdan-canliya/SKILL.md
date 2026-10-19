---
name: sifirdan-canliya
description: Bir websitesini sıfırdan canlıya, GitHub'dan yönetilen otomatik deploy ile alma rehberi; hangi skill'in hangi adımda kullanılacağını sıralar. Kullanıcı "/sifirdan-canliya" yazdığında çalışır.
disable-model-invocation: true
---

# Sıfırdan canlıya

Kullanıcıya ne yapmak istediğini sor ve aşağıdaki rotalardan birini öner. Her adımı ilgili skill'le yürüt; bir adımın "bitti" koşulu sağlanmadan sonrakine geçme.

Her rotanın sonu aynı: site GitHub'dan yönetilir. Değişiklik PR'la gelir, PR'da önizleme ya da Terraform planı görülür, `main`'e merge edilince otomatik yayına çıkar.

## Rotalar

| Rota | Ne zaman | Sıra |
|---|---|---|
| Netlify | En hızlı yol, hiç sunucu yok | `arac-kontrol` → `github-cicd` → `netlify-yayin` |
| Cloudflare Pages | Netlify'ın kredi sınırı istenmiyorsa | `arac-kontrol` → `github-cicd` → `cloudflare-pages` |
| AWS S3 + CloudFront | AWS'de sunucusuz, en ucuz | `arac-kontrol` → `aws-hesap-guvenligi` → `github-cicd` → `aws-cicd-temeli` → `aws-statik-site` |
| AWS EC2 | Sunucu öğrenmek, sunucuda bir şey çalıştırmak | `arac-kontrol` → `aws-hesap-guvenligi` → `github-cicd` → `aws-cicd-temeli` (`enable_ec2=true`) → `aws-ec2-site` |

Rotalar birleşebilir: aynı repo ve aynı `site/` klasörü hem Netlify'a hem AWS'ye yayınlanabilir; her rota kendi workflow'unu getirir.

**Kendi domain'i:** `alan-adi` (kayıt firmasından al, DNS Cloudflare'de, Netlify'a bağla). Tek ücretli kalem.

**Dinamik parça:** iletişim formu için `iletisim-formu` (Cloudflare Worker + Turnstile + Resend; domain gerekir); veritabanı için `supabase-veritabani` (ziyaretçi defteri; migration'lar da CI'dan).

**Bitiş:** iş bir demoysa `bulut-temizlik`: envanter, onay, silme.

## Her rotada geçerli

- Şablonlar Türkiye'deki ziyaretçiler ve ücretsiz kullanım için sabitlendi (Frankfurt, CloudFront `PriceClass_100`, `t3.micro`); neden ve ücretsizlik koşulları `turkiye-ucretsiz`.
- Her bulut kaynağı `project=<proje-adı>` etiketi taşır; varsayılan proje adı `demo`.
- Kullanıcı ayrıntıları bilmek zorunda değil: kurulum adımlarını (repo, PR açma, merge, silme içermeyen Terraform planının apply'ı) sormadan yürüt, her adımı tek satırla bildir. Durup onay iste sadece şunlarda: bir şey silinecekse (planda `destroy` / `replace`, `sites:delete`, `repo delete`) ve ücretli bir kaynak ilk kez kurulacaksa (EC2).
- Token, şifre ve anahtarları kullanıcı kendi terminalinde girer (`gh secret set …`); sohbete yapıştırılmaz.
- Bitirirken kullanıcıya ver: canlı URL, repo URL'i, oluşturulan kaynakların listesi, silme yolu.
