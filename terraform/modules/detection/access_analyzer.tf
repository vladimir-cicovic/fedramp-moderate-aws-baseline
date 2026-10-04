# IAM Access Analyzer (AC-2(3), AC-3, AC-6, AC-6(9), CA-7)
# External access analyzer: finds resources (S3, KMS, IAM roles, SQS, Secrets
# Manager, Lambda layers, ...) shared with principals outside the account.

resource "aws_accessanalyzer_analyzer" "external_access" {
  analyzer_name = "${var.name_prefix}-external-access"
  type          = "ACCOUNT"
}

resource "aws_accessanalyzer_analyzer" "unused_access" {
  count = var.enable_unused_access_analyzer ? 1 : 0

  analyzer_name = "${var.name_prefix}-unused-access"
  type          = "ACCOUNT_UNUSED_ACCESS"

  configuration {
    unused_access {
      unused_access_age = var.unused_access_age
    }
  }
}
