# bucket ve region init sırasında verilir: -backend-config="bucket=..." -backend-config="region=..."
terraform {
  backend "s3" {
    key          = "ec2-site/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
