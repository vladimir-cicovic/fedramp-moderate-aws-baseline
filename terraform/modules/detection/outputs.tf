output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "security_hub_arn" {
  value = aws_securityhub_account.this.arn
}

output "security_hub_standards" {
  value = { for k, s in aws_securityhub_standards_subscription.this : k => s.id }
}

output "inspector_resource_types" {
  value = aws_inspector2_enabler.this.resource_types
}

output "conformance_pack_arn" {
  value = var.enable_conformance_pack ? aws_config_conformance_pack.nist_800_53_rev5[0].arn : null
}

output "access_analyzer_arns" {
  value = merge(
    { external_access = aws_accessanalyzer_analyzer.external_access.arn },
    var.enable_unused_access_analyzer ? { unused_access = aws_accessanalyzer_analyzer.unused_access[0].arn } : {}
  )
}

output "config_aggregator_arn" {
  value = var.enable_config_aggregator ? aws_config_configuration_aggregator.organization[0].arn : null
}

output "event_rules" {
  value = {
    guardduty_high_severity   = aws_cloudwatch_event_rule.guardduty_high_severity.arn
    securityhub_critical_high = aws_cloudwatch_event_rule.securityhub_critical_high.arn
  }
}
