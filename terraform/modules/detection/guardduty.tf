# Amazon GuardDuty (SI-4, SI-4(4), SI-3, IR-4, IR-6, RA-5)
# Threat detection over CloudTrail management events, VPC Flow Logs, DNS logs,
# S3 data events, EKS audit logs, RDS login activity, Lambda network.

resource "aws_guardduty_detector" "this" {
  #checkov:skip=CKV2_AWS_3:Single-account lab in one region; organization-wide auto-enable belongs to the delegated administrator account
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"

  depends_on = [aws_guardduty_detector_feature.s3_data_events]
}

resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"

  depends_on = [aws_guardduty_detector_feature.eks_audit_logs]
}

resource "aws_guardduty_detector_feature" "rds_login_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RDS_LOGIN_EVENTS"
  status      = "ENABLED"

  depends_on = [aws_guardduty_detector_feature.ebs_malware_protection]
}

resource "aws_guardduty_detector_feature" "lambda_network_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "LAMBDA_NETWORK_LOGS"
  status      = "ENABLED"

  depends_on = [aws_guardduty_detector_feature.rds_login_events]
}

resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  detector_id = aws_guardduty_detector.this.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }

  additional_configuration {
    name   = "ECS_FARGATE_AGENT_MANAGEMENT"
    status = "ENABLED"
  }

  additional_configuration {
    name   = "EC2_AGENT_MANAGEMENT"
    status = "ENABLED"
  }

  depends_on = [aws_guardduty_detector_feature.lambda_network_logs]
}
