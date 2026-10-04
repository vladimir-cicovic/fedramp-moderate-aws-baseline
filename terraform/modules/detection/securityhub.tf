# AWS Security Hub CSPM (CA-7, RA-5, SI-4, CM-6, AU-6(1))
# Continuous control evaluation against NIST SP 800-53 Rev 5, NIST SP 800-171
# Rev 2 (the CMMC Level 2 practice set) and AWS Foundational Security Best.

resource "aws_securityhub_account" "this" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = toset(var.security_hub_standards)

  standards_arn = "arn:${var.partition}:securityhub:${var.region}::standards/${each.value}"

  depends_on = [aws_securityhub_account.this]
}
