# Cryptography baseline (SC-12, SC-13, SC-28, SC-28(1), AC-5)
# AWS KMS is FIPS 140-3 validated (Level 3 HSMs).

# Data key with separation of duties between administrators and users

data "aws_iam_policy_document" "data_key" {
  # Root retains administrative control so the key can never become
  # unmanageable.
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

  # Key administrators: manage the key, cannot encrypt or decrypt with it.
  dynamic "statement" {
    for_each = length(var.key_administrator_arns) > 0 ? [1] : []
    content {
      sid    = "KeyAdministrators"
      effect = "Allow"
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
        "kms:RotateKeyOnDemand",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_administrator_arns
      }
    }
  }

  # Key users: cryptographic operations only, no key management.
  dynamic "statement" {
    for_each = length(var.key_user_arns) > 0 ? [1] : []
    content {
      sid    = "KeyUsers"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_user_arns
      }
    }
  }

  # Lets integrated services (EBS, Auto Scaling, RDS) create grants on behalf
  # of
  # the key users.
  dynamic "statement" {
    for_each = length(var.key_user_arns) > 0 ? [1] : []
    content {
      sid    = "KeyUsersGrantsForAwsResources"
      effect = "Allow"
      actions = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_user_arns
      }

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }
    }
  }
}

resource "aws_kms_key" "data" {
  description             = "General purpose data-at-rest key: EBS default, S3, Aurora, Secrets Manager"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.data_key.json
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name_prefix}-data"
  target_key_id = aws_kms_key.data.key_id
}

# Account-wide defaults

# Every new EBS volume and snapshot in this region is encrypted, with the
# customer managed key rather than the AWS managed one (SC-28).
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  key_arn = aws_kms_key.data.arn
}

# No bucket in this account can be made public, regardless of bucket policy
# or ACL (AC-3, SC-7, AC-22).
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
