terraform {
  # use_lockfile (S3 native kilit) 1.10 ile geldi.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  # Türkiye'deki ziyaretçiler için: Türkiye'ye yakın, varsayılan açık region. Statik içeriği CloudFront İstanbul'dan verir.
  region = "eu-central-1"

  default_tags {
    tags = {
      project    = var.project
      managed-by = "terraform"
    }
  }
}
