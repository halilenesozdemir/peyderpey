---
name: aws-cicd-temeli
description: AWS'de GitHub Actions ile sürekli teslimatın temelini bir kere kurar - Terraform state bucket'ı, GitHub OIDC provider, salt okunur plan rolü ve sadece main'e güvenen deploy rolü, GitHub değişkenleri. aws-statik-site ya da aws-ec2-site'tan önce, ya da "OIDC", "terraform state", "github actions aws yetkisi" geçtiğinde kullan.
---

# AWS CI/CD temeli (bootstrap)

S3 ve EC2 rotalarının ikisi de bu temeli kullanır. Bir kere, kullanıcının bilgisayarından kurulur; sonrasında AWS'ye sadece GitHub Actions yazar.

Ön koşul: `aws-hesap-guvenligi` bitmiş (SSO profili, bütçe alarmı), `github-cicd` adım 1 bitmiş (repo push edilmiş), Terraform 1.10+.

## Ne kurulur

| Kaynak | Görevi |
|---|---|
| `<proje>-tfstate-<hesap>` bucket'ı | Site katmanlarının state'i; sürümlü, şifreli, public kapalı |
| GitHub OIDC provider | GitHub'ın AWS'den kalıcı anahtar olmadan geçici yetki almasını sağlar |
| `<proje>-github-plan` rolü | PR'larda `terraform plan`; salt okunur, repodaki her dal ve PR kullanabilir |
| `<proje>-github-deploy` rolü | `main`'de apply ve içerik yükleme; sadece `<proje>-site-*` ve `<proje>-web-*` kaynaklarına yazar |

Bu skill'in `templates/*.tf` dosyalarını repoda `infra/bootstrap/` altına kopyala. Bootstrap state'i lokal dosyada kalır (`.gitignore` onu dışarıda tutar). Kullanıcıya söyle: bu klasör silinirse bootstrap kaynakları Terraform'dan kopar ve elle silinmesi gerekir.

## 1. Kur

```bash
export AWS_PROFILE=demo
aws sts get-caller-identity
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[].Arn' --output text
```

Çıktıda `token.actions.githubusercontent.com` varsa `create_oidc_provider=false` (hesap başına bir tane olabilir). EC2 rotası kullanılacaksa `enable_ec2=true`.

GitHub'ın bu repo için gönderdiği OIDC kimlik önekini al. Yeni repolar ID'li biçim kullanır (`repo:<sahip>@<id>/<repo>@<id>`); eski biçimi beklemek `Not authorized to perform sts:AssumeRoleWithWebIdentity` hatası verir:

```bash
PFX=$(gh api repos/<sahip>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix)
echo "$PFX"     # boşsa eski biçim kullanılır, -var satırını çıkar
```

```bash
cd infra/bootstrap
terraform init
terraform plan -out tfplan \
  -var project=<proje> \
  -var github_repo=<sahip>/<repo> \
  -var "github_sub_prefix=$PFX" \
  -var enable_ec2=<true|false> \
  -var create_oidc_provider=<true|false>
```

Silme planında da aynı `-var` değerlerini kullan.

Plan özetinde `0 to destroy` ise sormadan `terraform apply tfplan` çalıştır ve eklenen kaynak sayısını bildir. Silme ya da değiştirme varsa dur, listeyi göster, onay iste.

## 2. GitHub değişkenleri

```bash
gh variable set PROJECT --body "<proje>"
gh variable set TF_STATE_BUCKET --body "$(terraform output -raw state_bucket)"
gh variable set AWS_PLAN_ROLE_ARN --body "$(terraform output -raw plan_role_arn)"
gh variable set AWS_DEPLOY_ROLE_ARN --body "$(terraform output -raw deploy_role_arn)"
gh variable list
```

Hepsi değişken, hiçbiri gizli değil. Secret gerekmez.

## Bitti sayılır

`gh variable list` dört değişkeni gösteriyor. Sıradaki adım: `aws-statik-site` ya da `aws-ec2-site`.

## Güvenlik notları

- Deploy rolünün güven koşulu `<önek>:ref:refs/heads/main`. ID'li önek, repo silinip aynı adla yeniden açılırsa eski rolün yeni repoya güvenmemesini sağlar: yeniden açılan repo için bootstrap yeni önekle tekrar apply edilir. Workflow'a `environment:` eklenirse gelen kimlik `<önek>:environment:<ad>` olur ve rol alınamaz; o durumda koşul güncellenir.
- Plan rolü PR'larda çalışır; salt okunur olduğu için PR'daki kod bir şey değiştiremez. Bu yüzden plan `-lock=false` ile çalışır, kilidi sadece apply alır.
- `enable_ec2=true` deploy rolüne `<proje>-web-*` adlı IAM rollerini yönetme izni verir. Demo için yeterli; gerçek projede bu rollere bir permissions boundary eklenmeli.

## Silme

Site katmanları silindikten **sonra** (state'leri bu bucket'ta durur):

```bash
cd infra/bootstrap
terraform plan -destroy -out tfplan -var project=<proje> -var github_repo=<sahip>/<repo> -var enable_ec2=<…> -var create_oidc_provider=<…>
```

Listeyi göster, onay alınca `terraform apply tfplan`. Hesapta başka bir proje aynı OIDC provider'ı kullanıyorsa ve burada `create_oidc_provider=true` ile kurulduysa, silmeden önce kullanıcıya sor.
