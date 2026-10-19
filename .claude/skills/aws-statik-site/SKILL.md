---
name: aws-statik-site
description: Statik bir siteyi AWS'de sunucusuz olarak S3 + CloudFront (private bucket, OAC, HTTPS) üzerinde Terraform ile kurar ve GitHub Actions'a bağlar - PR'da plan yorumu, main'e merge'de apply + içerik yükleme. "S3", "CloudFront", "AWS'de statik site" istendiğinde ya da CloudFront 403 / eski içerik sorununda kullan.
---

# AWS'de statik site: S3 + CloudFront

Sunucu yok: dosyalar private bir S3 bucket'ında durur, CloudFront HTTPS ile dağıtır. En ucuz ve en az bakım isteyen AWS rotası. Sunucu üzerinde çalışan bir şey gerekiyorsa `aws-ec2-site`.

Ön koşul: `aws-cicd-temeli` bitmiş (`gh variable list` dört değişkeni gösteriyor).

## Ne kurulur

Private S3 bucket (`<proje>-site-…`), CloudFront Origin Access Control (bucket'ı sadece CloudFront okur), CloudFront dağıtımı (HTTPS yönlendirme, `index.html` kök nesne, en ucuz fiyat sınıfı), bucket policy. Hepsi `project` ve `managed-by=terraform` etiketli.

Bu skill'in `templates/` klasöründen kopyala:
- `*.tf` → `infra/s3-site/`
- `aws-s3.yml` → `.github/workflows/aws-s3.yml`

## 1. İlk teslimat

```bash
git checkout -b aws-s3
git add infra/s3-site .github/workflows/aws-s3.yml site
git commit -m "S3 + CloudFront altyapısı ve CD"
git push -u origin aws-s3
gh pr create --fill
gh pr checks --watch
```

PR'daki "Terraform plan: S3 + CloudFront" yorumunu oku (`gh pr view --comments`): `Plan: 5 to add, 0 to change, 0 to destroy` beklenir. Silme yoksa ve kontroller yeşilse sormadan merge et; silme varsa dur ve kullanıcıya göster.

```bash
gh pr merge --squash --delete-branch
gh run watch
```

İlk apply'da CloudFront 5–10 dakika sürer. Bittiğinde çalışma özetinde "Yayında: https://…cloudfront.net" çıkar (`gh run view`).

## 2. Sonraki değişiklikler

`site/**` ya da `infra/s3-site/**` değişikliği → PR → plan yorumu → merge → otomatik yayın. Lokalde plan görmek için:

```bash
cd infra/s3-site
terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=eu-central-1"
terraform plan -var project=<proje> -lock=false
```

Lokalde `apply` çalıştırma; state'e tek yazar CI'dır.

## Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| `Could not assume role` | Güven koşulu tutmuyor | `aws-cicd-temeli` › Güvenlik notları |
| `AccessDenied` apply'da | `PROJECT` değişkeni bootstrap'teki `project`'ten farklı | İkisini eşitle |
| 403 kök adreste | `site/index.html` yok | Dosya adı |
| 403 her yerde, ilk dakikalarda | Dağıtım hâlâ kuruluyor | `aws cloudfront get-distribution --id <id> --query Distribution.Status` → `Deployed` |
| Eski içerik | Tarayıcı önbelleği (CloudFront'unkini workflow temizler) | Gizli sekme |
| Alt sayfa 403 | S3 dizin indeksi yapmaz | Bağlantılar `hakkinda.html` biçiminde |

## Özel domain (istenirse)

CloudFront'un sertifikası **us-east-1**'deki ACM'den gelir; başka region'da açılan sertifika görünmez. İkinci bir `provider "aws" { alias = "us_east_1" region = "us-east-1" }`, `aws_acm_certificate` (DNS doğrulama), dağıtıma `aliases` ve `viewer_certificate { acm_certificate_arn = …, ssl_support_method = "sni-only" }` gerekir; deploy rolüne `acm:*` izni eklenir.

## Silme

```bash
cd infra/s3-site
terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=eu-central-1"
terraform plan -destroy -out tfplan -var project=<proje>
```

Listeyi göster, onay alınca `terraform apply tfplan`. Workflow dosyasını da kaldıran bir PR aç; yoksa sonraki merge siteyi yeniden kurar. Bootstrap'i silmek: `aws-cicd-temeli` › Silme.

## Kullanıcıya teslim

Canlı URL, akış özeti (PR = plan, merge = yayın) ve silme sırası.
