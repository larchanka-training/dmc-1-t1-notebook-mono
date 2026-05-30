variable "region"      { default = "eu-north-1" }
variable "project"     { default = "dmc-1-t1-notebook" }
variable "environment" { default = "dev" }

module "shared" {
  source      = "../../shared"
  region      = var.region
  project     = var.project
  environment = var.environment
}

module "environment" {
  source                = "../../modules/environment"
  environment           = var.environment
  project               = var.project
  region                = var.region
  vpc_id                = module.shared.vpc_id
  private_subnet_ids    = module.shared.private_subnet_ids
  public_subnet_ids     = module.shared.public_subnet_ids
  api_target_group_arn  = module.shared.api_target_group_arn
  ui_target_group_arn   = module.shared.ui_target_group_arn
  alb_security_group_id = module.shared.alb_security_group_id
  ecs_security_group_id = module.shared.ecs_security_group_id
  rds_security_group_id = module.shared.rds_security_group_id
  alb_dns_name          = module.shared.alb_dns_name
}

# ---------------------------------------------------------------------------
# PR Preview: S3 + CloudFront (global, dev-only)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "preview" {
  bucket = "${var.project}-previews"
}

resource "aws_s3_bucket_public_access_block" "preview" {
  bucket = aws_s3_bucket.preview.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "preview" {
  bucket = aws_s3_bucket.preview.id

  rule {
    id     = "expire-previews"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}

resource "aws_cloudfront_origin_access_control" "preview" {
  name                              = "${var.project}-preview-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.project}-preview-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      var match = uri.match(/^(\/pr-\d+)(\/[^.]*)?$/);
      if (match) {
        request.uri = match[1] + '/index.html';
      }
      return request;
    }
  EOF
}

resource "aws_cloudfront_distribution" "preview" {
  enabled = true
  comment = "${var.project} PR Previews"

  origin {
    domain_name              = aws_s3_bucket.preview.bucket_regional_domain_name
    origin_id                = "s3-preview"
    origin_access_control_id = aws_cloudfront_origin_access_control.preview.id
  }

  origin {
    domain_name = module.shared.alb_dns_name
    origin_id   = "dev-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # /api/v1/* → dev ALB, без кэша
  ordered_cache_behavior {
    path_pattern     = "/api/v1/*"
    target_origin_id = "dev-alb"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies { forward = "all" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # /* → S3 статика + SPA rewrite
  default_cache_behavior {
    target_origin_id       = "s3-preview"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
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

resource "aws_s3_bucket_policy" "preview" {
  bucket = aws_s3_bucket.preview.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.preview.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.preview.arn
        }
      }
    }]
  })
}
