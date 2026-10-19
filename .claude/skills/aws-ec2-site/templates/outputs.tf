output "url" {
  value = "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "bucket" {
  value = aws_s3_bucket.content.id
}

output "instance_id" {
  value = aws_instance.web.id
}

output "distribution_id" {
  value = aws_cloudfront_distribution.web.id
}
