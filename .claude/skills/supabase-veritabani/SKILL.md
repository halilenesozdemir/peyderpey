---
name: supabase-veritabani
description: Statik siteye Supabase ile veritabanı ekler - migration dosyası, Row Level Security, tarayıcıdan supabase-js ile okuma/yazma ve migration'ların GitHub Actions'la otomatik uygulanması. "supabase", "ziyaretçi defteri", "iletişim formu", "veritabanı ekle", "RLS" geçtiğinde kullan.
---

# Supabase

Sonuç: tarayıcı veritabanına doğrudan yazar ve okur, güvenliği RLS kuralları sağlar. Şema değişiklikleri `supabase/migrations/` altında dosya olarak durur ve `main`'e merge edilince GitHub Actions uygular.

Ön koşul: `supabase` ve `gh` girişli (`arac-kontrol`), repo push edilmiş (`github-cicd` adım 1).

## Anahtarlar: hangisi nereye

| Anahtar | Nerede durur | Neden |
|---|---|---|
| Publishable / anon key | Tarayıcı kodunda, açıkça | Herkese görünür; ne yapabileceğini RLS belirler |
| Secret / service_role key | Sadece sunucu tarafında | RLS'i atlar; tarayıcıya giren bu anahtarla herkes her şeyi silebilir |
| Access token, DB şifresi | GitHub secret'ı | CI'ın migration uygulaması için |

Tarayıcı koduna yalnızca publishable/anon anahtar ve proje URL'i girer.

## 1. Proje

Kullanıcının mevcut bir projesi yoksa Supabase panelinden (New project) açmasını iste: ad, güçlü bir veritabanı şifresi (şifre yöneticisine kaydetsin), region **Central EU (Frankfurt)** (Türkiye'deki ziyaretçiler için en uygunu; `turkiye-ucretsiz`). Ücretsiz planda bir hafta kullanılmayan proje duraklatılır; panelden tek tıkla açılır. Frankfurt ücretsiz planda da seçilebilir; ama Supabase o bölgede kapasite dolunca yeni proje açmayı geçici olarak kapatabiliyor (status.supabase.com). Panel izin vermezse **Central Europe (Zurich)** seç ya da birkaç saat sonra tekrar dene.

Proje referansı panelde Project Settings › General › Project ID'dir.

## 2. Migration

```bash
supabase init
supabase link --project-ref <ref>      # DB şifresini sorar: kullanıcı kendi terminalinde girsin
supabase migration new ziyaretci_defteri
```

Oluşan `supabase/migrations/<zaman>_ziyaretci_defteri.sql` dosyasına bu skill'in `templates/ziyaretci_defteri.sql` içeriğini koy ya da kullanıcının ihtiyacına göre yaz. Her yeni tablo için:
- `enable row level security` satırı zorunlu.
- Her işlem (select, insert, update, delete) için ayrı ve açık bir policy; anonim kullanıcıya update/delete verme, kullanıcı açıkça istemedikçe.
- Metin alanlarına uzunluk sınırı (`check`): spam ve kötüye kullanımı sınırlar.

## 3. Site tarafı

Proje URL'i ve publishable/anon anahtar panelde Project Settings › API Keys'te. Bunları kullanıcıdan al ya da `supabase projects api-keys --project-ref <ref>` ile listele; sadece publishable/anon olanı koda koy.

```html
<script type="module">
  import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
  const supabase = createClient("https://<ref>.supabase.co", "<publishable-veya-anon-key>");

  const { data } = await supabase.from("mesajlar")
    .select("isim, mesaj, created_at")
    .order("created_at", { ascending: false })
    .limit(50);

  // form gönderiminde:
  await supabase.from("mesajlar").insert({ isim, mesaj });
</script>
```

Mesajları sayfaya `textContent` ile yaz, `innerHTML` ile değil: kullanıcıdan gelen metin HTML olarak çalışmasın.

## 4. CI/CD

Bu skill'in `templates/supabase.yml` dosyasını `.github/workflows/supabase.yml` olarak kopyala. PR'da hangi migration'ların uygulanacağını gösterir (`--dry-run`), `main`'de uygular.

```bash
gh variable set SUPABASE_PROJECT_REF --body "<ref>"
```

Secret'ları kullanıcı kendi terminalinde girer (`github-cicd` adım 2):
- `gh secret set SUPABASE_ACCESS_TOKEN`: Supabase › Account › Access Tokens'dan üretilir.
- `gh secret set SUPABASE_DB_PASSWORD`: 1. adımdaki şifre.

Migration'ı lokalde `supabase db push` ile değil, PR + merge ile uygula: tek yazar CI olsun.

## 5. Doğrula

Merge sonrası `gh run watch`, sonra sitede formu doldur ve listede gör. RLS'i kontrol et: anon anahtarla silme denemesi hata vermeli ya da 0 satır silmeli.

```bash
curl -s -X DELETE "https://<ref>.supabase.co/rest/v1/mesajlar?id=gt.0" \
  -H "apikey: <anon-key>" -H "Authorization: Bearer <anon-key>" -H "Prefer: return=representation"
```

`[]` dönmesi = hiçbir şey silinmedi, RLS çalışıyor.

## Kullanıcıya teslim

Tablo ve policy listesi, sitede formun çalıştığı, anahtar tablosu (hangisi nerede) ve silme yolu: panelde Project Settings › General › Delete project.
