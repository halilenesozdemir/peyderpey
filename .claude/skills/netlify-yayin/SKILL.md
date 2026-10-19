---
name: netlify-yayin
description: Statik bir siteyi Netlify'da yayına alır ve GitHub Actions'tan yönetilir hale getirir - PR'da önizleme linki, main'e merge'de production. "netlify", "siteyi yayınla", "canlıya al", "önizleme linki" geçtiğinde ya da hızlı bir landing page / portfolyo istendiğinde kullan.
---

# Netlify + GitHub Actions

Sonuç: Netlify sitesi **sadece GitHub'dan** yönetilir. Kod `main`'e girince production'a çıkar, her PR kendi önizleme linkini alır. Netlify panelinde repo bağlantısı kurulmaz; deploy'u Actions yapar, böylece süreç tek yerde görünür.

Ön koşul: `gh` ve `netlify` girişli (`arac-kontrol`).

Netlify'ın ücretsiz planı kredi tabanlıdır: ayda 300 kredi, her production deploy 15 kredi (yaklaşık 20 merge), bant genişliği de krediden düşer. Sık merge edilecek bir sınıf projesi ya da kalabalık bir ekip için `cloudflare-pages` rotasını öner; iki rota aynı repoda birlikte de çalışır.

## 1. Site

- Klasörde site yoksa `site/` altına `index.html` ve `style.css` yaz: framework yok, build yok, mobil uyumlu, tek sayfa. Kullanıcının verdiği içeriği kullan; vermediyse yer tutucu metin koy ve bunu söyle.
- Mevcut proje build istiyorsa (`package.json` içinde `build`), yayın klasörü build çıktısıdır (`dist/`, `build/`, `out/`). Dosyalara bakıp hangisi olduğunu bul; aşağıda `site` geçen her yerde onu kullan ve workflow'daki build satırını aç.

## 2. Repo

`github-cicd` skill'inin 1. adımı: repo, `.gitignore`, ilk push. `.gitignore`'a `.netlify/` de ekle.

## 3. Siteyi oluştur, ilk yayın

Site adı Netlify genelinde benzersiz olmalı: `<repo-adı>-<4 rastgele harf>` öner.

```bash
netlify deploy --prod --dir site --no-build --site-name <site-adı> --json | jq '{site_id, url}'
```

Bu komut siteyi açar, klasöre bağlar ve yayınlar; `site_id` sonraki adımda lazım. `Failed to create site: 404` alırsan ya da birden fazla takım varsa `--team <slug>` ekle. Slug takım adından farklı olabilir: `netlify api listAccountsForUser | jq -r '.[] | "\(.name)  \(.slug)"'` ikisini birlikte listeler. Site ID'si sonradan da `.netlify/state.json` içindeki `siteId` alanında durur.

## 4. GitHub'a bağla

Workflow: bu skill'in `templates/netlify.yml` dosyasını `.github/workflows/netlify.yml` olarak kopyala.

Değişken ve secret (`github-cicd` adım 2):

```bash
gh variable set NETLIFY_SITE_ID --body "<site-id>"
```

`NETLIFY_AUTH_TOKEN` kullanıcının tek elle yaptığı adım; Netlify API'si token üretmez ve değeri senin görmemen gerekir. Netlify CLI'ın makinedeki oturum token'ını okuyup kullanma: süresiz ve tüm hesaba erişir.

Token sayfasını aç ve kullanıcıya tek komut bırak:

```bash
open "https://app.netlify.com/user/applications#personal-access-tokens" 2>/dev/null \
  || xdg-open "https://app.netlify.com/user/applications#personal-access-tokens"
```

Kullanıcıya şunu söyle, başka bir şey değil:
1. Açılan sayfada **New access token** › bir ad ve son kullanma tarihi (30 gün) › Generate › kopyala.
2. Terminalde `gh secret set NETLIFY_AUTH_TOKEN --repo <sahip>/<repo>` çalıştır, istemde yapıştır.

Bitti dediğinde `gh secret list` ile adın göründüğünü kontrol et. Liste değerin dolu olduğunu göstermez: `gh workflow run netlify.yml --ref main` ile bir çalışma başlat, "Ayarları kontrol et" adımı geçmeli. "secret'ı yok" hatası secret'ın boş kaydedildiğini gösterir (istemde yapıştırmadan Enter); kullanıcıdan tekrar girmesini iste. Token'ın süresi dolunca workflow `Unauthorized` verir; aynı iki adım tekrarlanır.

## 5. Akışı dene

```bash
git checkout -b ilk-degisiklik
# site/index.html içinde küçük bir değişiklik
git commit -am "başlık güncellendi" && git push -u origin ilk-degisiklik
gh pr create --fill
gh run watch
```

PR'a "Netlify önizleme: https://pr-<n>--<site-adı>.netlify.app" yorumu düşer. Linki kullanıcıya ver; kontroller yeşilse merge et (kullanıcı önizlemeye bakmak istediğini söylediyse onu bekle):

```bash
gh pr merge --squash --delete-branch
gh run watch
curl -sI https://<site-adı>.netlify.app | head -1
```

`200` ve yeni içerik görünüyorsa bitti.

## Kullanıcıya teslim

Canlı URL, repo URL'i, akışın tek cümlelik özeti (PR = önizleme, merge = yayın) ve silme komutları: `netlify sites:delete <site-id>`, `gh repo delete <sahip>/<repo>` (ayrıntı: `bulut-temizlik`).
