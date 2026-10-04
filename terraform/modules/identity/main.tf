# IAM account password policy (IA-5, IA-5(1))
# Applies only to IAM users.

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = var.password_policy.max_password_age
  password_reuse_prevention      = var.password_policy.password_reuse_prevention
  hard_expiry                    = false
}

# GitHub Actions OIDC federation (IA-2, IA-5(7), AC-6)
# CI/CD authenticates with short-lived STS credentials.

locals {
  github_oidc_url  = "https://token.actions.githubusercontent.com"
  github_oidc_host = "token.actions.githubusercontent.com"
  repo_sub_prefix  = "repo:${var.github_org}/${var.github_repo}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = local.github_oidc_url
  client_id_list = ["sts.amazonaws.com"]

  # AWS validates GitHub's token signing certificates against its own trusted
  # CA store; the thumbprints are kept for compatibility.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# Role 1: plan / static analysis from any branch or pull request. Read-only.
data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    sid     = "GitHubActionsPlan"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.github_oidc_host}:sub"
      values   = ["${local.repo_sub_prefix}:*"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${var.name_prefix}-github-plan"
  description          = "Read-only role for terraform plan and drift detection from GitHub Actions."
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "github_plan_security_audit" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/SecurityAudit"
}

# Role 2: continuous monitoring evidence collection. Only the main branch,
# only
# the read APIs the collector needs (least privilege, AC-6(1)).
data "aws_iam_policy_document" "github_evidence_trust" {
  statement {
    sid     = "GitHubActionsEvidenceMainBranchOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = ["${local.repo_sub_prefix}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "evidence_collector" {
  #checkov:skip=CKV_AWS_356:Read-only inventory of the whole account; scoping to specific resources would blind the evidence collector to new resources
  statement {
    sid    = "SecurityHubRead"
    effect = "Allow"
    actions = [
      "securityhub:BatchGetSecurityControls",
      "securityhub:BatchGetStandardsControlAssociations",
      "securityhub:DescribeHub",
      "securityhub:DescribeStandards",
      "securityhub:DescribeStandardsControls",
      "securityhub:GetEnabledStandards",
      "securityhub:GetFindings",
      "securityhub:ListSecurityControlDefinitions",
      "securityhub:ListStandardsControlAssociations",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ConfigRead"
    effect = "Allow"
    actions = [
      "config:DescribeComplianceByConfigRule",
      "config:DescribeConfigRules",
      "config:DescribeConfigurationRecorderStatus",
      "config:DescribeConfigurationRecorders",
      "config:DescribeConformancePackCompliance",
      "config:DescribeConformancePackStatus",
      "config:DescribeConformancePacks",
      "config:DescribeDeliveryChannels",
      "config:GetComplianceDetailsByConfigRule",
      "config:GetComplianceSummaryByConfigRule",
      "config:GetConformancePackComplianceDetails",
      "config:GetConformancePackComplianceSummary",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IamRead"
    effect = "Allow"
    actions = [
      "iam:GenerateCredentialReport",
      "iam:GetAccountPasswordPolicy",
      "iam:GetAccountSummary",
      "iam:GetCredentialReport",
      "iam:GetOpenIDConnectProvider",
      "iam:GetRole",
      "iam:ListAccountAliases",
      "iam:ListAttachedRolePolicies",
      "iam:ListMFADevices",
      "iam:ListOpenIDConnectProviders",
      "iam:ListPolicies",
      "iam:ListRoles",
      "iam:ListUsers",
      "iam:ListVirtualMFADevices",
      "access-analyzer:ListAnalyzers",
      "access-analyzer:ListFindings",
      "access-analyzer:ListFindingsV2",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DetectionServicesRead"
    effect = "Allow"
    actions = [
      "guardduty:GetDetector",
      "guardduty:GetFindings",
      "guardduty:GetFindingsStatistics",
      "guardduty:ListDetectors",
      "guardduty:ListFindings",
      "inspector2:BatchGetAccountStatus",
      "inspector2:ListCoverage",
      "inspector2:ListFindingAggregations",
      "inspector2:ListFindings",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTrails",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "OrganizationAndIdentityCenterRead"
    effect = "Allow"
    actions = [
      "organizations:DescribeOrganization",
      "organizations:DescribePolicy",
      "organizations:ListAccounts",
      "organizations:ListOrganizationalUnitsForParent",
      "organizations:ListPolicies",
      "organizations:ListPoliciesForTarget",
      "organizations:ListRoots",
      "sso:DescribePermissionSet",
      "sso:ListAccountAssignments",
      "sso:ListAccountsForProvisionedPermissionSet",
      "sso:ListInstances",
      "sso:ListManagedPoliciesInPermissionSet",
      "sso:ListPermissionSets",
      "identitystore:DescribeGroup",
      "identitystore:DescribeUser",
      "identitystore:ListGroupMemberships",
      "identitystore:ListGroups",
      "identitystore:ListUsers",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EncryptionStorageAndMonitoringRead"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:ListKeys",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:ListAllMyBuckets",
      "ec2:DescribeFlowLogs",
      "ec2:DescribeVpcs",
      "ec2:GetEbsEncryptionByDefault",
      "logs:DescribeLogGroups",
      "logs:DescribeMetricFilters",
      "cloudwatch:DescribeAlarms",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTopics",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "evidence_collector" {
  name        = "${var.name_prefix}-evidence-collector"
  description = "Read-only permissions for automated NIST 800-53 evidence collection."
  policy      = data.aws_iam_policy_document.evidence_collector.json
}

resource "aws_iam_role" "github_evidence" {
  name                 = "${var.name_prefix}-github-evidence"
  description          = "Evidence collection role for GitHub Actions (main branch only)."
  assume_role_policy   = data.aws_iam_policy_document.github_evidence_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_evidence" {
  role       = aws_iam_role.github_evidence.name
  policy_arn = aws_iam_policy.evidence_collector.arn
}
