# Near-real-time alerting on CloudTrail events (AU-6, AU-6(1), SI-4, SI-4(5),
# AC-2(4), IR-6)

locals {
  metric_namespace = "CloudTrailMetrics"

  alarms = {
    unauthorized-api-calls = {
      description = "Unauthorized API calls or access denied errors (AC-6, SI-4)."
      pattern     = <<-EOT
        { ($.errorCode = "*UnauthorizedOperation") || ($.errorCode = "AccessDenied*") }
      EOT
    }
    console-signin-without-mfa = {
      description = "Console sign-in by an IAM user without MFA (IA-2(1))."
      pattern     = <<-EOT
        { ($.eventName = "ConsoleLogin") && ($.additionalEventData.MFAUsed != "Yes") && ($.userIdentity.type = "IAMUser") && ($.responseElements.ConsoleLogin = "Success") }
      EOT
    }
    root-account-usage = {
      description = "Any use of the root account (AC-6(5))."
      pattern     = <<-EOT
        { $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }
      EOT
    }
    iam-policy-changes = {
      description = "IAM policy created, deleted, attached or detached (AC-2(4), CM-5)."
      pattern     = <<-EOT
        { ($.eventSource = iam.amazonaws.com) && (($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy)) }
      EOT
    }
    cloudtrail-configuration-changes = {
      description = "CloudTrail trail created, updated, deleted, started or stopped (AU-9)."
      pattern     = <<-EOT
        { ($.eventName = CreateTrail) || ($.eventName = UpdateTrail) || ($.eventName = DeleteTrail) || ($.eventName = StartLogging) || ($.eventName = StopLogging) }
      EOT
    }
    console-authentication-failures = {
      description = "Failed console authentication attempts (AC-7)."
      pattern     = <<-EOT
        { ($.eventName = ConsoleLogin) && ($.errorMessage = "Failed authentication") }
      EOT
    }
    kms-key-disabled-or-scheduled-deletion = {
      description = "Customer managed KMS key disabled or scheduled for deletion (SC-12)."
      pattern     = <<-EOT
        { ($.eventSource = kms.amazonaws.com) && (($.eventName = DisableKey) || ($.eventName = ScheduleKeyDeletion)) }
      EOT
    }
    s3-bucket-policy-changes = {
      description = "S3 bucket policy, ACL, CORS, lifecycle or replication changed (CM-3, AC-3)."
      pattern     = <<-EOT
        { ($.eventSource = s3.amazonaws.com) && (($.eventName = PutBucketAcl) || ($.eventName = PutBucketPolicy) || ($.eventName = PutBucketCors) || ($.eventName = PutBucketLifecycle) || ($.eventName = PutBucketReplication) || ($.eventName = DeleteBucketPolicy) || ($.eventName = DeleteBucketCors) || ($.eventName = DeleteBucketLifecycle) || ($.eventName = DeleteBucketReplication)) }
      EOT
    }
    config-configuration-changes = {
      description = "AWS Config recorder or delivery channel changed (AU-9, CM-6)."
      pattern     = <<-EOT
        { ($.eventSource = config.amazonaws.com) && (($.eventName = StopConfigurationRecorder) || ($.eventName = DeleteDeliveryChannel) || ($.eventName = PutDeliveryChannel) || ($.eventName = PutConfigurationRecorder)) }
      EOT
    }
    security-group-changes = {
      description = "Security group created, deleted or rules changed (SC-7, CM-3)."
      pattern     = <<-EOT
        { ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }
      EOT
    }
    network-acl-changes = {
      description = "Network ACL created, deleted or entries changed (SC-7, CM-3)."
      pattern     = <<-EOT
        { ($.eventName = CreateNetworkAcl) || ($.eventName = CreateNetworkAclEntry) || ($.eventName = DeleteNetworkAcl) || ($.eventName = DeleteNetworkAclEntry) || ($.eventName = ReplaceNetworkAclEntry) || ($.eventName = ReplaceNetworkAclAssociation) }
      EOT
    }
    network-gateway-changes = {
      description = "Internet or customer gateway created, deleted, attached or detached (SC-7)."
      pattern     = <<-EOT
        { ($.eventName = CreateCustomerGateway) || ($.eventName = DeleteCustomerGateway) || ($.eventName = AttachInternetGateway) || ($.eventName = CreateInternetGateway) || ($.eventName = DeleteInternetGateway) || ($.eventName = DetachInternetGateway) }
      EOT
    }
    route-table-changes = {
      description = "Route table or route created, replaced or deleted (SC-7)."
      pattern     = <<-EOT
        { ($.eventSource = ec2.amazonaws.com) && (($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable)) }
      EOT
    }
    vpc-changes = {
      description = "VPC created, deleted, modified or peered (SC-7)."
      pattern     = <<-EOT
        { ($.eventName = CreateVpc) || ($.eventName = DeleteVpc) || ($.eventName = ModifyVpcAttribute) || ($.eventName = AcceptVpcPeeringConnection) || ($.eventName = CreateVpcPeeringConnection) || ($.eventName = DeleteVpcPeeringConnection) || ($.eventName = RejectVpcPeeringConnection) || ($.eventName = AttachClassicLinkVpc) || ($.eventName = DetachClassicLinkVpc) || ($.eventName = DisableVpcClassicLink) || ($.eventName = EnableVpcClassicLink) }
      EOT
    }
  }
}

# Security alerts topic

resource "aws_sns_topic" "security_alerts" {
  name              = "${var.name_prefix}-security-alerts"
  kms_master_key_id = aws_kms_key.alerts.id
}

data "aws_iam_policy_document" "security_alerts_topic" {
  statement {
    sid       = "AllowCloudWatchAndEventBridgeToPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]

    principals {
      type = "Service"
      identifiers = [
        "cloudwatch.amazonaws.com",
        "events.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.security_alerts.arn]

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

resource "aws_sns_topic_policy" "security_alerts" {
  arn    = aws_sns_topic.security_alerts.arn
  policy = data.aws_iam_policy_document.security_alerts_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != null ? 1 : 0

  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Metric filters and alarms

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = local.alarms

  name           = "${var.name_prefix}-${each.key}"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = trimspace(each.value.pattern)

  metric_transformation {
    name          = each.key
    namespace     = local.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = each.value.description
  namespace           = local.metric_namespace
  metric_name         = each.key
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.security_alerts.arn]

  depends_on = [aws_cloudwatch_log_metric_filter.this]
}
