output "cloudtrail_arn" {
  value = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket_name" {
  value = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_bucket_arn" {
  value = aws_s3_bucket.cloudtrail.arn
}

output "config_bucket_name" {
  value = aws_s3_bucket.config.id
}

output "access_logs_bucket_name" {
  value = aws_s3_bucket.access_logs.id
}

output "cloudtrail_log_group_name" {
  value = aws_cloudwatch_log_group.cloudtrail.name
}

output "cloudtrail_log_group_arn" {
  value = aws_cloudwatch_log_group.cloudtrail.arn
}

output "logging_kms_key_arn" {
  value = aws_kms_key.logging.arn
}

output "alerts_kms_key_arn" {
  value = aws_kms_key.alerts.arn
}

output "security_alerts_topic_arn" {
  value = aws_sns_topic.security_alerts.arn
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.this.name
}

output "config_role_arn" {
  value = aws_iam_role.config.arn
}
