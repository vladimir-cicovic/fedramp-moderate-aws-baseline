output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "origin_bucket_name" {
  value = aws_s3_bucket.origin.id
}

output "waf_log_group_name" {
  value = aws_cloudwatch_log_group.waf.name
}

output "access_log_group_name" {
  value = aws_cloudwatch_log_group.cloudfront.name
}
