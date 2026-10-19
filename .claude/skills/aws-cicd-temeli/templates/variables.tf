variable "project" {
  description = "Tüm kaynaklara project etiketi olarak yazılır; site katmanındakiyle aynı olmalı."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project))
    error_message = "project küçük harf, rakam ve tire içermeli, 3-30 karakter."
  }
}

variable "github_repo" {
  description = "Deploy edecek repo, sahip/ad biçiminde (örn. ornek-kullanici/sitem)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repo))
    error_message = "github_repo sahip/ad biçiminde olmalı."
  }
}

variable "github_sub_prefix" {
  description = "OIDC sub öneki. Yeni repolar ID'li biçim kullanır: gh api repos/<sahip>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix"
  type        = string
  default     = null
}

variable "enable_ec2" {
  description = "EC2 rotası kullanılacaksa true: deploy rolüne EC2, SSM ve <project>-web-* IAM izinleri eklenir."
  type        = bool
  default     = false
}

variable "create_oidc_provider" {
  description = "Hesapta GitHub OIDC provider zaten varsa false (hesap başına bir tane olabilir)."
  type        = bool
  default     = true
}
