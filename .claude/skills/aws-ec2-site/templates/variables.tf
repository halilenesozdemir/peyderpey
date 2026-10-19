variable "project" {
  description = "Tüm kaynaklara project etiketi olarak yazılır; bootstrap'teki project ile aynı olmalı."
  type        = string
  default     = "demo"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project))
    error_message = "project küçük harf, rakam ve tire içermeli, 3-30 karakter."
  }
}
