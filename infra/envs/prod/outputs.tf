output "cloudfront_domain_name" {
  value       = module.shared.cloudfront_domain_name
  description = "Prod HTTPS URL via CloudFront"
}
