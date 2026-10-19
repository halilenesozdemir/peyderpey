---
name: turkiye-ucretsiz
description: Bu skill'lerin şablonlarına sabit yazılmış ayarları açıklar - ziyaretçileri Türkiye'de olan bir site için region, CloudFront, EC2, Supabase ve Netlify seçimleri ve her parçanın ücretsiz kalma koşulu. "region", "Türkiye", "ücretsiz mi", "free tier", "fatura çıkar mı", "neden Frankfurt" geçtiğinde, ya da Supabase projesi açılırken kullan.
---

# Türkiye için ücretsiz kurulum

Şablonlar iki hedefe göre sabitlendi: **ziyaretçiler Türkiye'de** ve **her şey ücretsiz**. Bu ayarlar değişken değil, kodun içinde yazılı; kullanıcının bir şey seçmesi gerekmez.

## Sabit ayarlar

| Ayar | Değer | Nerede yazılı | Neden |
|---|---|---|---|
| AWS region | `eu-central-1` (Frankfurt) | `versions.tf` (provider), workflow'larda `AWS_REGION` ve `-backend-config` | Türkiye'ye yakın, varsayılan açık (opt-in gerekmez), Free Tier servislerinin hepsi var |
| CloudFront fiyat sınıfı | `PriceClass_100` | `main.tf` | En ucuz sınıf; AWS fiyat tablosunda "Europe, Israel, and Türkiye" grubunu kapsar, Türkiye'deki ziyaretçi İstanbul uç noktalarından alır |
| EC2 tipi | `t3.micro` | `aws-ec2-site` `main.tf` | Frankfurt'ta Free Tier uygun tip; şablondaki x86 AMI ile uyumlu |
| EC2 disk | 8 GB gp3 | `aws-ec2-site` `main.tf` | Free Tier'ın 30 GB sınırının altında |
| Ağ | Default VPC, NAT Gateway yok | `aws-ec2-site` `main.tf` | NAT Gateway saatlik ücretlidir |
| Supabase | Central EU (Frankfurt) | Proje açılırken panelde | Supabase'in Türkiye ya da Orta Doğu bölgesi yok; sonradan değiştirilemez. Free planda da seçilebilir; kapasite yüzünden geçici kapalıysa Zurich |
| Netlify | Ayar yok | — | Statik dosyalar küresel CDN'den verilir |

Kullanıcıya bu seçimleri sadece sorarsa anlat. Hangi skill çalışıyorsa onun içinde sessizce uygulanırlar.

## Ne ücretsiz, hangi koşulla?

| Parça | Ücretsiz mi? |
|---|---|
| GitHub (public repo, Actions) | Evet |
| Netlify (statik site, önizleme linkleri) | Evet, ücretsiz plan |
| CloudFront | Evet, her ay 1 TB ve 10 milyon istek süresiz ücretsiz |
| S3 (site dosyaları, Terraform state) | Birkaç MB; Free plan kredisinden düşer, kredi bitse de ayda bir sentin altında |
| EC2 `t3.micro` + disk + public IPv4 | Free plan kredisinden düşer (yeni hesaplar) ya da 12 aylık Free Tier'da ayda 750 saat ücretsiz (eski hesaplar). Kredi ya da süre bitince ücretli: rotalar içinde ücretsiz kalma süresi sınırlı olan tek parça |
| Supabase | Evet, ücretsiz plan; bir hafta kullanılmayan proje durdurulur, panelden tek tıkla açılır |

**Domain:** tek ücretli kalem ve isteğe bağlı (`alan-adi`). Domain olmadan `netlify.app`, `pages.dev`, `cloudfront.net` adresleri yeterli; e-posta göndermek (Resend) domain ister.

**Tamamen ve süresiz ücretsiz rota:** Netlify ya da S3 + CloudFront, isteğe bağlı Supabase. EC2 rotası öğrenmek için kurulur ve iş bitince `bulut-temizlik` ile silinir.

## Ücretli bir şeyi fark etmeden açmamak

Şu durumlarda dur ve kullanıcıya söyle; bu kurulumun parçası değiller:
- Free Tier dışı bir EC2 tipi, NAT Gateway, RDS, Elastic IP, Load Balancer.
- Netlify Functions: ücretsiz planda bölge seçilemez ve fonksiyonlar ABD'de (Ohio) çalışır; Türkiye'deki ziyaretçi için her istek uzar. Dinamik parça için tarayıcıdan Supabase'e doğrudan bağlan (`supabase-veritabani`).
- CloudFront için `PriceClass_100` dışında bir fiyat sınıfı: Türkiye'ye bir şey eklemez, maliyeti artırır.

Bütçe alarmı (`aws-hesap-guvenligi`) her durumda ilk kuruşta haber verir.

## Kaynaklar

- AWS region'ları ve opt-in: https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html
- CloudFront fiyat sınıfları: https://aws.amazon.com/cloudfront/pricing/pay-as-you-go
- AWS Free Tier: https://aws.amazon.com/free
- Supabase bölgeleri: https://supabase.com/docs/guides/platform/regions
- Netlify Functions bölgesi: https://docs.netlify.com/build/functions/optional-configuration/
