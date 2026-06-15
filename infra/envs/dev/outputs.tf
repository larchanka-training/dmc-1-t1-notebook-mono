output "alb_dns_name" {
  value       = module.shared.alb_dns_name
  description = "Dev ALB DNS name (HTTP only — use cloudfront_domain_name for HTTPS)"
}

output "cloudfront_domain_name" {
  value       = module.shared.cloudfront_domain_name
  description = "Dev HTTPS URL via CloudFront"
}

output "preview_s3_bucket" {
  value       = aws_s3_bucket.preview.bucket
  description = "S3 bucket name for PR previews — set as GHA Variable S3_PREVIEW_BUCKET in dmc-1-t1-notebook-ui"
}

output "preview_cf_distribution_id" {
  value       = aws_cloudfront_distribution.preview.id
  description = "CloudFront distribution ID for PR previews — set as GHA Variable CF_DISTRIBUTION_ID in dmc-1-t1-notebook-ui"
}

output "preview_cf_domain" {
  value       = aws_cloudfront_distribution.preview.domain_name
  description = "CloudFront domain for PR previews — set as GHA Variable CF_DOMAIN in dmc-1-t1-notebook-ui"
}
