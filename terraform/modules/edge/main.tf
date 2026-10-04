# Edge: CloudFront + WAFv2 in front of a private S3 origin
# (SC-7, SC-7(4), SC-8, SC-8(1), SC-5, SI-10, AU-2)

# Origin

resource "aws_s3_bucket" "origin" {
  #checkov:skip=CKV_AWS_145:Public static content; SSE-S3 is sufficient and keeps OAC simple
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed for static content
  #checkov:skip=CKV_AWS_144:Cross-region replication is a production enhancement (CP-10), out of scope for the lab
  #checkov:skip=CKV_AWS_18:Access to the origin is logged at the edge (CloudFront access logs); the bucket is reachable only by CloudFront
  bucket        = "${var.name_prefix}-origin-${var.account_id}-${var.region}"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "origin" {
  bucket = aws_s3_bucket.origin.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket                  = aws_s3_bucket.origin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "origin" {
  bucket = aws_s3_bucket.origin.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "origin" {
  bucket = aws_s3_bucket.origin.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.origin]
}

locals {
  index_html = <<-HTML
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><title>${var.name_prefix}</title></head>
    <body><h1>${var.name_prefix}</h1><p>Static origin behind CloudFront, WAFv2 and origin access control.</p></body></html>
  HTML
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.origin.id
  key          = "index.html"
  content_type = "text/html; charset=utf-8"
  content      = local.index_html
  etag         = md5(local.index_html)
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-s3-oac"
  description                       = "SigV4-signed requests from CloudFront to the private origin bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_iam_policy_document" "origin_bucket" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.origin.arn,
      "${aws_s3_bucket.origin.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  bucket = aws_s3_bucket.origin.id
  policy = data.aws_iam_policy_document.origin_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.origin]
}

# Distribution

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.name_prefix}-security-headers"
  comment = "HSTS, no sniffing, no framing, strict referrer, CSP."

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }

    content_security_policy {
      content_security_policy = "default-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
      override                = true
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV2_AWS_47:The attached web ACL includes AWSManagedRulesKnownBadInputsRuleSet; see waf.tf
  #checkov:skip=CKV_AWS_174:TLS 1.2 minimum requires a custom domain certificate (acm_certificate_arn); the default *.cloudfront.net certificate does not allow setting it
  #checkov:skip=CKV_AWS_86:Access logging uses CloudWatch Logs standard logging v2 (aws_cloudwatch_log_delivery), not the legacy S3 logging_config this check looks for
  #checkov:skip=CKV_AWS_310:Origin failover is a production enhancement (CP-10); a single private S3 origin in the lab
  #checkov:skip=CKV_AWS_374:Geo restriction is a business decision; FedRAMP does not require it and the lab serves a placeholder page
  enabled             = true
  comment             = "${var.name_prefix} edge: WAF, OAC, security headers, HTTPS only"
  default_root_object = "index.html"
  http_version        = "http2and3"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.this.arn
  aliases             = var.aliases

  origin {
    origin_id                = "s3-origin"
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    target_origin_id           = "s3-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # With a custom certificate: SNI and TLS 1.2 (2021 policy, FIPS-compatible
  # cipher suites).
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }
}
