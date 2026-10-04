# Finding notifications (AU-6(1), IR-4, IR-6, SI-4(5))
# EventBridge forwards actionable findings to the security alerts topic: -
# GuardDuty findings with severity >= 7 (High, Critical) - Security Hub.

resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "${var.name_prefix}-guardduty-high-severity"
  description = "GuardDuty findings with severity 7.0 or higher."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_high_severity_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high_severity.name
  target_id = "security-alerts"
  arn       = var.security_alerts_topic_arn

  input_transformer {
    input_paths = {
      account  = "$.detail.accountId"
      region   = "$.detail.region"
      severity = "$.detail.severity"
      type     = "$.detail.type"
      title    = "$.detail.title"
      id       = "$.detail.id"
    }
    input_template = "\"[GuardDuty] severity <severity> <type> in <account>/<region>: <title> (finding <id>). Runbook: runbooks/IR-002-guardduty-high-severity.md\""
  }
}

resource "aws_cloudwatch_event_rule" "securityhub_critical_high" {
  name        = "${var.name_prefix}-securityhub-critical-high"
  description = "New CRITICAL or HIGH Security Hub findings from vulnerability and access products."

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity    = { Label = ["CRITICAL", "HIGH"] }
        Workflow    = { Status = ["NEW"] }
        RecordState = ["ACTIVE"]
        ProductName = [{ anything-but = ["Security Hub", "GuardDuty"] }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "securityhub_critical_high_sns" {
  rule      = aws_cloudwatch_event_rule.securityhub_critical_high.name
  target_id = "security-alerts"
  arn       = var.security_alerts_topic_arn

  input_transformer {
    input_paths = {
      product  = "$.detail.findings[0].ProductName"
      severity = "$.detail.findings[0].Severity.Label"
      title    = "$.detail.findings[0].Title"
      resource = "$.detail.findings[0].Resources[0].Id"
      account  = "$.detail.findings[0].AwsAccountId"
    }
    input_template = "\"[Security Hub] <severity> from <product> in <account>: <title>. Resource: <resource>. Runbook: runbooks/VM-001-vulnerability-management.md\""
  }
}
