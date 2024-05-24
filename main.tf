data "aws_caller_identity" "current" {}

########################
# S3 Buckets
########################
resource "aws_s3_bucket" "com_jawhite04" {
  bucket = "com-jawhite04-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_ownership_controls" "com_jawhite04" {
  bucket = aws_s3_bucket.com_jawhite04.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "com_jawhite04" {
  bucket = aws_s3_bucket.com_jawhite04.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "com_jawhite04" {
  bucket = aws_s3_bucket.com_jawhite04.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.com_jawhite04.id
  key          = "index.html"
  source       = "src/index.html"
  acl          = "public-read"
  content_type = "text/html"
}

resource "aws_s3_bucket_policy" "com_jawhite04" {
  bucket = aws_s3_bucket.com_jawhite04.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "${aws_cloudfront_origin_access_identity.s3_distribution.iam_arn}"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.com_jawhite04.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "com_jawhite04_logging" {
  bucket = "logging-${aws_s3_bucket.com_jawhite04.bucket}"
}

resource "aws_s3_bucket_ownership_controls" "com_jawhite04_logging" {
  bucket = aws_s3_bucket.com_jawhite04_logging.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "com_jawhite04_logging" {
  bucket = aws_s3_bucket.com_jawhite04_logging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "com_jawhite04_logging" {
  depends_on = [
    aws_s3_bucket_ownership_controls.com_jawhite04_logging,
    aws_s3_bucket_public_access_block.com_jawhite04_logging,
  ]

  bucket = aws_s3_bucket.com_jawhite04_logging.id
  acl    = "log-delivery-write"
}

# resource "aws_s3_bucket_logging" "com_jawhite04_logging" {
#   bucket        = aws_s3_bucket.com_jawhite04.id
#   target_bucket = aws_s3_bucket.com_jawhite04_logging.id
#   target_prefix = "logs-s3/"
# }

########################
# ACM Certificate
########################
data "aws_route53_zone" "com_zone" {
  provider = aws.route53
  name     = "jawhite04.com."

}

resource "aws_acm_certificate" "com_jawhite04" {
  domain_name       = "jawhite04.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.api.jawhite04.com",
    "*.jawhite04.com"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "com_dns_validation" {
  provider = aws.route53
  for_each = {
    for dvo in aws_acm_certificate.com_jawhite04.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.com_zone.zone_id
}

resource "aws_acm_certificate_validation" "com_dns_validation" {
  certificate_arn         = aws_acm_certificate.com_jawhite04.arn
  validation_record_fqdns = [for record in aws_route53_record.com_dns_validation : record.fqdn]
}

########################
# Cloudfront Distribution
########################
resource "aws_cloudfront_origin_access_identity" "s3_distribution" {
  comment = "S3 bucket OAI"
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.com_jawhite04.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${self.id} --paths '/*'"
  }

  origin {
    origin_id   = local.s3_origin_id
    domain_name = aws_s3_bucket.com_jawhite04.bucket_regional_domain_name

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_distribution.cloudfront_access_identity_path
    }
  }

  aliases = ["jawhite04.com"]
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.com_jawhite04.arn
    ssl_support_method  = "sni-only"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = local.s3_origin_id
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # logging_config {
  #   bucket = aws_s3_bucket.com_jawhite04_logging.bucket_regional_domain_name
  #   prefix = "logs-cloudfront/"
  # }
}

########################
# Route53 Record for Cloudfront
########################
resource "aws_route53_record" "www" {
  provider = aws.route53
  zone_id  = data.aws_route53_zone.com_zone.zone_id
  name     = data.aws_route53_zone.com_zone.name
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
