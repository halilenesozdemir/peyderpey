---
name: github-cicd
description: GitHub tarafını gh CLI ile hazırlar - repo, .gitignore, Actions secret ve değişkenleri, main dalını PR'a kilitleyen koruma, PR akışı ve çalışan workflow'u izleme; başarısız bir Actions çalışmasının sebebini bulur. "github actions", "ci/cd", "otomatik deploy", "secret ekle", "workflow neden kırmızı" geçtiğinde kullan.
---

# GitHub ve CI/CD

Netlify ve AWS skill'leri kendi workflow dosyalarını getirir; bu skill hepsinin ortak GitHub tarafıdır.

## 1. Repo

```bash
git init -b main 2>/dev/null || true
cat >> .gitignore <<'EOF'
.env
.env.*
node_modules/
.netlify/
.terraform/
*.tfstate*
*.tfvars
tfplan
EOF
git add . && git status --short
```

`git status` çıktısında `.env`, anahtar, `*.pem` ya da `tfstate` görürsen dur ve kullanıcıya göster. Temizse:

```bash
git commit -m "ilk sürüm"
gh repo create <repo-adı> --public --source=. --push
```

Kullanıcı başka bir şey söylemediyse varsayılanları kullan (ad: klasör adı, görünürlük: public) ve seçtiğini bildir. Branch koruması private repolarda ücretsiz planda çalışmaz; private seçilirse adım 3'ü atla ve bunu söyle.

## 2. Secret mı, değişken mi?

| Tür | Ne için | Komut |
|---|---|---|
| Değişken (`vars.X`) | Gizli olmayan: site ID, rol ARN'i, bucket adı | `gh variable set X --body "<değer>"` |
| Secret (`secrets.X`) | Token, şifre | Kullanıcı kendi terminalinde: `gh secret set X` |

Secret değerini asla sen yazma, sohbete yapıştırtma; `gh secret set` değeri istemde kullanıcıdan alır. Kontrol: `gh variable list`, `gh secret list` (değer göstermez).

AWS için secret gerekmez: workflow'lar OIDC ile geçici yetki alır (`aws-cicd-temeli`).

Etkileşimli komutları (`gh secret set`, `gh auth …`) kullanıcı kendi terminalinde çalıştırır; ajanın sohbetten komut çalıştırma kısayolu varsa (örn. Claude Code'da `!` öneki) o da olur.

## 3. main'i koru

Doğrudan push yerine her değişiklik PR'dan geçsin, böylece önizleme ve plan her zaman görülür:

```bash
gh api -X PUT "repos/{owner}/{repo}/branches/main/protection" --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null
}
EOF
```

Onay sayısı 0: tek kişilik projede kendi PR'ını merge edebilirsin, ama PR açmak zorunludur. `enforce_admins: false` acil durumda sahibin doğrudan push etmesine izin verir.

## 4. Günlük akış

```bash
git checkout -b <dal>
# değişiklik
git commit -am "<ne değişti>" && git push -u origin <dal>
gh pr create --fill
gh pr checks --watch        # PR kontrolleri: önizleme / plan
gh pr merge --squash --delete-branch
gh run watch                # main'deki deploy
```

## 5. Kırmızı çalışma

```bash
gh run list --limit 5
gh run view <run-id> --log-failed
```

| Hata | Sebep | Çözüm |
|---|---|---|
| `Could not assume role with OIDC` / `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Rolün güven koşulu GitHub'ın gönderdiği `sub` ile eşleşmiyor ya da workflow'da `id-token: write` yok | `gh api repos/<sahip>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix` çıktısını rolün koşuluyla karşılaştır (`aws-cicd-temeli` › `github_sub_prefix`); `permissions` bloğuna bak; workflow'a `environment:` eklendiyse koşul `<önek>:environment:<ad>` olmalı |
| `Unauthorized` (Netlify) | `NETLIFY_AUTH_TOKEN` yok ya da süresi dolmuş | Kullanıcı yeni token üretip `gh secret set` ile günceller |
| `Resource not accessible by integration` | PR'a yorum yazma izni yok | Workflow'da `pull-requests: write` |
| Fork'tan gelen PR'da secret boş | GitHub fork PR'larına secret vermez | Beklenen davranış; dal repo içinde açılmalı |
| `terraform fmt -check` başarısız | Biçim | Lokalde `terraform fmt -recursive`, commit |

Düzeltmeyi yeni bir commit olarak aynı PR'a push et; `gh run rerun <run-id>` sadece geçici hatalar için.
