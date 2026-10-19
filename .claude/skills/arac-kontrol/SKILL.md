---
name: arac-kontrol
description: gh, aws, netlify, supabase, terraform CLI'larının kurulu ve giriş yapılmış olduğunu kontrol eder, eksikleri kurdurur. Bir deploy veya bulut işine başlamadan önce, ya da "command not found", "not logged in", "ExpiredToken" hatasında kullan.
---

# Araç kontrolü

Amaç: işe başlamadan önce gereken her CLI'ın **kurulu** ve **giriş yapılmış** olduğunu görmek. Sadece işin gerektirdiği araçları kontrol et.

## 1. Kurulu mu?

```bash
for t in gh aws netlify supabase terraform; do
  printf '%-10s ' "$t"; command -v "$t" >/dev/null && "$t" --version 2>&1 | head -1 || echo "YOK"
done
```

Eksik olanı kullanıcının işletim sistemine göre kur ve neyi kurduğunu bildir:

| Araç | macOS (Homebrew) | Diğer |
|---|---|---|
| gh | `brew install gh` | https://cli.github.com |
| aws | `brew install awscli` | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| netlify | `npm install -g netlify-cli` | aynı (Node.js gerekir) |
| supabase | `brew install supabase/tap/supabase` | https://supabase.com/docs/guides/cli |
| terraform | `brew install hashicorp/tap/terraform` | https://developer.hashicorp.com/terraform/install |

Terraform **1.10 veya üstü** olmalı (S3 state kilidi `use_lockfile` için). Homebrew'un çekirdek deposundaki `terraform` formülü 1.5.7'de kaldı. Sürüm eskiyse:
- `tfenv` kuruluysa (`command -v tfenv`): `tfenv install 1.10.5` ve repo köküne `echo 1.10.5 > .terraform-version`. tfenv bu dosyayı görünce o klasörde doğru sürümü kendisi seçer; arkadaşların makinesinde de aynı sürüm çalışır.
- Değilse: `brew uninstall terraform && brew install hashicorp/tap/terraform`.

OpenTofu 1.10+ da çalışır (`tofu` komutuyla).

## 2. Giriş yapılmış mı?

| Araç | Kontrol | Giriş |
|---|---|---|
| gh | `gh auth status` | `gh auth login` |
| aws | `aws sts get-caller-identity` | `aws sso login --profile <profil>` (profil yoksa `aws-hesap-guvenligi`) |
| netlify | `netlify status` | `netlify login` |
| supabase | `supabase projects list` | `supabase login` |

Giriş komutları tarayıcı açar ve etkileşimlidir: kullanıcıdan kendi terminalinde çalıştırmasını iste (ajanın sohbetten komut çalıştırma kısayolu varsa o da olur, örn. Claude Code'da `! gh auth login`). Token, şifre veya anahtarı sohbete yapıştırmasını isteme.

## Bitti sayılır

Gereken her araç için sürüm satırı ve başarılı bir giriş kontrolü görüldüğünde. Sonucu kısa bir tabloyla kullanıcıya bildir: araç, sürüm, giriş durumu (hesap adı).
