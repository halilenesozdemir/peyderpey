---
name: aws-hesap-guvenligi
description: Yeni bir AWS hesabını güvenli kullanıma hazırlar - SSO profili, kimlik kontrolü, sıfır harcama bütçe alarmı, Free Tier uyarıları. AWS'de ilk kaynak kurulmadan önce, "free tier", "fatura alarmı", "budget", "aws configure sso" geçtiğinde ya da "bu ay ne kadar harcadım" sorulduğunda kullan.
---

# AWS hesap güvenliği

Sıra önemli: kimlik → bütçe alarmı → ancak ondan sonra kaynak.

## 1. Root hesap (kullanıcı yapar, konsolda)

Kullanıcıya şu iki maddeyi yaptığını teyit ettir; sen yapamazsın:
- Root kullanıcıda MFA açık (IAM › Security credentials).
- Root kullanıcının access key'i yok. Günlük iş IAM Identity Center kullanıcısıyla yapılır.

Identity Center henüz yoksa: konsolda IAM Identity Center › Enable, bir kullanıcı oluştur, ona hesap üzerinde `AdministratorAccess` permission set'i ata. Bu adımları kullanıcıya listele.

## 2. SSO profili

Kullanıcının kendi terminalinde çalıştırması gerekir (tarayıcı açar):

```bash
aws configure sso          # profil adı önerisi: demo, region: eu-central-1
aws sso login --profile demo
```

Sonra her oturumda kimliği doğrula ve sonucu kullanıcıya göster:

```bash
aws sts get-caller-identity --profile demo
```

`Arn` içinde `:root` görürsen dur: kullanıcı root anahtarıyla çalışıyor, adım 1'e dön.
Bu skill'den sonraki tüm AWS komutlarına `--profile demo` ekle ya da `export AWS_PROFILE=demo` kullan.

## 3. Bütçe alarmı

Önce mevcut bütçelere bak; aynı adla ikinci bir bütçe açma:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws budgets describe-budgets --account-id "$ACCOUNT_ID" \
  --query 'Budgets[].BudgetName' --output text
```

Yoksa kullanıcıdan alarm e-postasını iste ve kur. 1 USD'lik bütçe, %1'i (1 sent) aşınca e-posta atar:

```bash
aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget '{"BudgetName":"sifir-harcama","BudgetLimit":{"Amount":"1","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":1,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"<e-posta>"}]}]'
```

Kullanıcıya ayrıca konsolda Billing › Billing preferences › "Receive Free Tier usage alerts" seçeneğini açmasını söyle.

## 4. Harcama sorgusu (istenirse)

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d tomorrow +%Y-%m-%d) \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

Cost Explorer API'si her istekte 0,01 USD alır: tek sorgu at, döngüye sokma. Sonucu servis bazında, sıfır olmayanlar üstte, tabloyla göster.

## Bilinen sessiz faturacılar

Kullanıcı bir şey kurmak istediğinde bunlardan biri işin içindeyse önceden uyar: NAT Gateway (saatlik ücret), public IPv4 adresi ve boştaki Elastic IP, RDS, bağlı olmayan EBS diskleri ve snapshot'lar, başka bir region'da unutulmuş kaynaklar.

## Bitti sayılır

`get-caller-identity` root olmayan bir ARN döndürdü ve `describe-budgets` çıktısında bir bütçe var.
