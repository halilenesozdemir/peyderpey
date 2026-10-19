data "aws_caller_identity" "current" {}

locals {
  oidc_url = "https://token.actions.githubusercontent.com"
  # Yeni repolarda sub "repo:<sahip>@<id>/<repo>@<id>:..." biçimindedir; eski biçim "repo:<sahip>/<repo>:...".
  sub_prefix = coalesce(var.github_sub_prefix, "repo:${var.github_repo}")
  oidc_arn   = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# --- Terraform state ---

resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
  # Demo kolay silinsin diye; gerçek projede false bırakın.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- GitHub OIDC ---

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = local.oidc_url
  client_id_list = ["sts.amazonaws.com"]
  # AWS artık GitHub için thumbprint doğrulamıyor; eski provider sürümleri alanı zorunlu tutuyor.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.oidc_url
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.sub_prefix}:*"]
    }
  }
}

# Sadece main dalı. Workflow'a "environment:" eklenirse sub "<önek>:environment:<ad>" olur ve bu koşul tutmaz.
data "aws_iam_policy_document" "trust_deploy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.sub_prefix}:ref:refs/heads/main"]
    }
  }
}

# --- plan rolü: PR'larda, salt okunur ---

resource "aws_iam_role" "plan" {
  name               = "${var.project}-github-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# --- deploy rolü: main'de apply + içerik yükleme ---

data "aws_iam_policy_document" "deploy" {
  statement {
    sid     = "State"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
  }

  statement {
    sid     = "SiteBucket"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project}-site-*",
      "arn:aws:s3:::${var.project}-site-*/*",
    ]
  }

  statement {
    sid       = "CloudFront"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust_deploy.json
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# --- EC2 rotası için ek izinler ---

data "aws_iam_policy_document" "deploy_ec2" {
  statement {
    sid     = "WebBucket"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project}-web-*",
      "arn:aws:s3:::${var.project}-web-*/*",
    ]
  }

  statement {
    sid       = "Ec2"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  statement {
    sid = "Ssm"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommands",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
    ]
    resources = ["*"]
  }

  # Sadece <project>-web-* adlı rol ve profiller: deploy rolü kendi yetkisini büyütemez.
  statement {
    sid     = "InstanceRole"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-web-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${var.project}-web-*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy_ec2" {
  count  = var.enable_ec2 ? 1 : 0
  name   = "deploy-ec2"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_ec2.json
}
