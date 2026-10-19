---
name: aws-ec2-site
description: Siteyi AWS'de bir EC2 sunucusunda (nginx) yayınlar - içerik private S3'te, önde CloudFront (HTTPS), SSH yerine SSM; Terraform ile kurulur, GitHub Actions'la PR'da plan, main'e merge'de apply + sunucuya dağıtım. "EC2", "sunucuya kur", "nginx", "VM'de yayınla" istendiğinde ya da EC2 sitesi açılmadığında kullan.
---

# AWS'de EC2 üzerinde site

Sunucu sizin: nginx bir EC2 instance'ında çalışır. Statik site için `aws-statik-site` daha ucuz ve bakımsızdır; bu rota sunucuyu öğrenmek ya da sunucuda çalışan bir şey (backend, özel nginx ayarı) eklemek için.

Ön koşul: `aws-cicd-temeli` **`enable_ec2=true`** ile kurulmuş. Değilse önce bootstrap'i bu değişkenle yeniden plan + apply et.

## Mimari

```
Ziyaretçi ─HTTPS→ CloudFront ─HTTP:80→ EC2 (nginx) ←sync─ S3 (private)
                                          ↑ SSM komutu
                              GitHub Actions (deploy rolü)
```

| Parça | Neden böyle |
|---|---|
| CloudFront önde | Domain olmadan ücretsiz HTTPS ve önbellek |
| Güvenlik grubu: 80 portu sadece CloudFront'un IP listesine | Sunucuya doğrudan erişilemez |
| SSH yok, port 22 kapalı | Yönetim SSM ile: anahtar dosyası yok, `aws ssm start-session` ile bağlanılır |
| İçerik S3'te | CI dosyayı S3'e koyar, sunucu oradan çeker; sunucu yenilenince içerik kaybolmaz |
| Amazon Linux 2023, IMDSv2 zorunlu, şifreli disk | Güncel ve güvenli varsayılanlar |
| Default VPC, public subnet | NAT Gateway yok (NAT saatlik ücretlidir) |

Bu skill'in `templates/` klasöründen kopyala:
- `*.tf` ve `user_data.sh.tftpl` → `infra/ec2-site/`
- `aws-ec2.yml` → `.github/workflows/aws-ec2.yml`

Hesapta default VPC yoksa (`aws ec2 describe-vpcs --filters Name=is-default,Values=true`) kullanıcıya söyle: `aws ec2 create-default-vpc` ile geri getirilebilir.

## Ücretsiz mi?

Şablondaki her şey Free Tier kapsamında seçildi: `t3.micro` (Frankfurt'ta Free Tier uygun tip), 8 GB gp3 disk, NAT Gateway yok, CloudFront `PriceClass_100`.

- **Free plan (Temmuz 2025 sonrası açılan hesaplar):** instance, disk ve public IPv4 adresinin saatlik ücreti Free plan kredisinden düşer; kart ücretlenmez. Kredi ya da Free plan süresi bitince ücretli olur.
- **Eski hesaplar (12 aylık Free Tier):** ayda 750 saat `t3.micro` ve 750 saat public IPv4 ücretsiz; tek instance tüm ay açık kalabilir.

S3 rotasından farkı: S3 + CloudFront kredi bitse de pratikte sıfır tutar, EC2 tutmaz. Kullanıcıya bunu tek cümleyle söyle ve demo bitince silinmesini hatırlat.

## 1. İlk teslimat

```bash
git checkout -b aws-ec2
git add infra/ec2-site .github/workflows/aws-ec2.yml site
git commit -m "EC2 + CloudFront altyapısı ve CD"
git push -u origin aws-ec2
gh pr create --fill
gh pr checks --watch
```

PR'daki "Terraform plan: EC2 + CloudFront" yorumunu oku (`gh pr view --comments`; yaklaşık 11 kaynak eklenir, hiçbiri silinmez). İlk kurulumda kullanıcıya "Ücretsiz mi?" bölümündeki notu tek cümleyle söyle ve onayını al; sonraki PR'larda silme yoksa ve kontroller yeşilse sormadan merge et.

```bash
gh pr merge --squash --delete-branch
gh run watch
```

Deploy adımı: apply → `site/` S3'e → instance'ın SSM'e kaydolması beklenir → SSM komutu sunucuda `aws s3 sync` çalıştırır → CloudFront önbelleği temizlenir. İlk çalışma 10 dakika sürebilir (CloudFront + sunucunun açılışı).

## 2. Sonraki değişiklikler

`site/**` ya da `infra/ec2-site/**` → PR → plan → merge → otomatik yayın. Sadece içerik değiştiyse Terraform "No changes" der ve yalnızca dağıtım çalışır.

Sunucuya bakmak için (kullanıcının terminalinde, Session Manager eklentisi gerekir):

```bash
aws ssm start-session --target "$(cd infra/ec2-site && terraform output -raw instance_id)"
```

## Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| Workflow "Instance SSM'de görünmedi" | Instance internete çıkamıyor ya da rol eksik | Default VPC'de public IP var mı, `AmazonSSMManagedInstanceCore` bağlı mı |
| CloudFront 502/504 | nginx çalışmıyor ya da güvenlik grubu CloudFront'u engelliyor | SSM oturumunda `systemctl status nginx`, `curl -I localhost` |
| nginx'in varsayılan sayfası görünüyor | Dağıtım cloud-init bitmeden çalıştı | Workflow'u `gh run rerun` |
| Eski içerik | CloudFront önbelleği | Workflow invalidation yapar; tarayıcıda gizli sekme |
| `AccessDenied` apply'da IAM ile ilgili | Bootstrap `enable_ec2=false` ile kurulmuş | Bootstrap'i `enable_ec2=true` ile tekrar apply |

## Silme

```bash
cd infra/ec2-site
terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=eu-central-1"
terraform plan -destroy -out tfplan -var project=<proje>
```

Listeyi göster, onay alınca `terraform apply tfplan`. Workflow dosyasını kaldıran bir PR aç. Bootstrap: `aws-cicd-temeli` › Silme.

## Kullanıcıya teslim

Canlı URL, instance ID, sunucuya bağlanma komutu, ücretsizlik notu ve silme sırası.
