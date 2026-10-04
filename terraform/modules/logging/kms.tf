# KMS keys (SC-12, SC-13, SC-28, AU-9)
# Two customer-managed keys with yearly automatic rotation: logging :
# CloudTrail, CloudWatch Logs, AWS Config delivery alerts : SNS security

locals {
  trail_name = "${var.name_prefix}-trail"
  trail_arn  = "arn:${var.partition}:cloudtrail:${var.region}:${var.account_id}:trail/${local.trail_name}"

  # An organization trail is always owned by the management account, even when
  # a delegated administrator creates it.
  admit_management_trail = (var.is_organization_trail || var.allow_management_trail) && var.management_account_id != null
  management_trail_name  = coalesce(var.management_trail_name, local.trail_name)
  org_trail_arn          = local.admit_management_trail ? "arn:${var.partition}:cloudtrail:${var.region}:${var.management_account_id}:trail/${local.management_trail_name}" : null
  trail_source_arns      = compact([local.trail_arn, local.org_trail_arn])
  trail_context_arns = compact([
    "arn:${var.partition}:cloudtrail:*:${var.account_id}:trail/*",
    local.admit_management_trail ? "arn:${var.partition}:cloudtrail:*:${var.management_account_id}:trail/*" : "",
  ])
}

data "aws_iam_policy_document" "logging_key" {
  # Root retains administrative control so the key can never become
  # unmanageable.
  # Actual use is granted to humans only through IAM policies on their roles.
  #checkov:skip=CKV_AWS_109:Root principal statement is the AWS-recommended default so the key can never become unmanageable; humans still need an IAM allow to use it
  #checkov:skip=CKV_AWS_111:Same as above; service principal statements are constrained with encryption-context, SourceArn or SourceAccount conditions
  #checkov:skip=CKV_AWS_356:Key policies always use Resource * (the resource is the key itself)
  statement {
    sid       = "EnableIamPoliciesForKeyAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${var.partition}:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudTrailEncryptLogs"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = local.trail_context_arns
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = local.trail_source_arns
    }
  }

  statement {
    sid       = "CloudTrailDescribeKey"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  # The identity that creates the organization trail in the management account
  # must be able to describe the key it points the trail at.
  dynamic "statement" {
    for_each = local.admit_management_trail ? [1] : []
    content {
      sid       = "ManagementAccountDescribeKeyForOrganizationTrail"
      effect    = "Allow"
      actions   = ["kms:DescribeKey"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = ["arn:${var.partition}:iam::${var.management_account_id}:root"]
      }
    }
  }

  statement {
    sid    = "CloudWatchLogsEncryptLogGroups"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${var.partition}:logs:${var.region}:${var.account_id}:log-group:*"]
    }
  }

  statement {
    sid    = "ConfigDeliverSnapshots"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_kms_key" "logging" {
  description             = "Audit logging key: CloudTrail, CloudWatch Logs, AWS Config"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.logging_key.json
}

resource "aws_kms_alias" "logging" {
  name          = "alias/${var.name_prefix}-logging"
  target_key_id = aws_kms_key.logging.key_id
}

data "aws_iam_policy_document" "alerts_key" {
  #checkov:skip=CKV_AWS_109:Root principal statement is the AWS-recommended default so the key can never become unmanageable; humans still need an IAM allow to use it
  #checkov:skip=CKV_AWS_111:Same as above; service principal statements are constrained with encryption-context, SourceArn or SourceAccount conditions
  #checkov:skip=CKV_AWS_356:Key policies always use Resource * (the resource is the key itself)
  statement {
    sid       = "EnableIamPoliciesForKeyAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${var.partition}:iam::${var.account_id}:root"]
    }
  }

  statement {
    sid    = "AlarmAndEventPublishersEncryptMessages"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

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
}

resource "aws_kms_key" "alerts" {
  description             = "Security alerts key: SNS topic encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.alerts_key.json
}

resource "aws_kms_alias" "alerts" {
  name          = "alias/${var.name_prefix}-alerts"
  target_key_id = aws_kms_key.alerts.key_id
}
