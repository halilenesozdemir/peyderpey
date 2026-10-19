locals {
  name = "${var.project}-web"
}

# --- İçerik bucket'ı: private, sadece instance okur ---

resource "aws_s3_bucket" "content" {
  bucket_prefix = "${local.name}-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "content" {
  bucket                  = aws_s3_bucket.content.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Instance rolü: SSM ile yönetim + bucket okuma, SSH anahtarı yok ---

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.name}-instance"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "content_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.content.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_role_policy" "content_read" {
  name   = "content-read"
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.content_read.json
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name}-instance"
  role = aws_iam_role.instance.name
}

# --- Ağ: default VPC, 80 portu sadece CloudFront'a açık ---

data "aws_vpc" "default" {
  default = true
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "web" {
  name = "${local.name}-sg"
  # SG açıklaması sadece ASCII ve kısıtlı noktalama kabul eder.
  description = "HTTP only from CloudFront"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "http_from_cloudfront" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

# nginx paketleri, S3 ve SSM uç noktaları için dışarı çıkış.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


# --- Instance ---

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro" # Free Tier uygun, Frankfurt'ta var
  iam_instance_profile        = aws_iam_instance_profile.instance.name
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    bucket = aws_s3_bucket.content.id
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = local.name
  }

  # Yeni AMI yayınlandıkça instance'ın yeniden yaratılmasını engeller.
  lifecycle {
    ignore_changes = [ami]
  }
}

# --- CloudFront: HTTPS ve önbellek, origin EC2 ---

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  comment             = "${var.project} EC2 site"
  default_root_object = "index.html"
  # En ucuz sınıf; "Europe, Israel, and Türkiye" grubunu kapsar, İstanbul uç noktaları dahil.
  price_class = "PriceClass_100"

  origin {
    origin_id   = "ec2"
    domain_name = aws_instance.web.public_dns

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "ec2"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
