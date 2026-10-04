# AWS Organizations
# Trusted access is enabled for every security service that will operate at
# the organization level (CloudTrail org trail, Config aggregator, GuardDuty.

data "aws_partition" "current" {}

resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  feature_set = "ALL"

  aws_service_access_principals = [
    "access-analyzer.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "guardduty.amazonaws.com",
    "inspector2.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

data "aws_organizations_organization" "existing" {
  count = var.create_organization ? 0 : 1
}

locals {
  org                   = var.create_organization ? aws_organizations_organization.this[0] : data.aws_organizations_organization.existing[0]
  organization_id       = local.org.id
  root_id               = local.org.roots[0].id
  management_account_id = local.org.master_account_id

  # Optional exemption so a designated security admin role can still perform
  # protected actions (break-glass / planned maintenance).
  has_admin_exemption = length(var.security_admin_role_arns) > 0
}

# Organizational units

resource "aws_organizations_organizational_unit" "this" {
  for_each = toset(var.organizational_units)

  name      = each.value
  parent_id = local.root_id
}

# Service Control Policies
# SCPs never apply to the management account.

# SCP 1: nobody can remove an account from the organization (CM-3, AC-6).
data "aws_iam_policy_document" "deny_leave_org" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

# SCP 2: root user is not allowed to do anything in member accounts (AC-6(5),
# IA-2).
data "aws_iam_policy_document" "deny_root_user" {
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${data.aws_partition.current.partition}:iam::*:root"]
    }
  }
}

# SCP 3: logging, detection and encryption services cannot be disabled or
# tampered with (AU-9, SI-4, CM-5).
data "aws_iam_policy_document" "protect_security_services" {
  statement {
    sid    = "ProtectSecurityServices"
    effect = "Deny"
    actions = [
      # CloudTrail
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:PutInsightSelectors",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      # GuardDuty
      "guardduty:CreateFilter",
      "guardduty:CreateIPSet",
      "guardduty:DeleteDetector",
      "guardduty:DeleteMembers",
      "guardduty:DisassociateFromAdministratorAccount",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:DisassociateMembers",
      "guardduty:StopMonitoringMembers",
      "guardduty:UpdateDetector",
      "guardduty:UpdateFilter",
      # Security Hub
      "securityhub:BatchDisableStandards",
      "securityhub:DeleteMembers",
      "securityhub:DisableSecurityHub",
      "securityhub:DisassociateFromAdministratorAccount",
      "securityhub:DisassociateFromMasterAccount",
      "securityhub:DisassociateMembers",
      "securityhub:UpdateStandardsControl",
      # AWS Config
      "config:DeleteAggregationAuthorization",
      "config:DeleteConfigRule",
      "config:DeleteConfigurationAggregator",
      "config:DeleteConfigurationRecorder",
      "config:DeleteConformancePack",
      "config:DeleteDeliveryChannel",
      "config:DeleteOrganizationConformancePack",
      "config:DeleteRetentionConfiguration",
      "config:PutConfigurationRecorder",
      "config:StopConfigurationRecorder",
      # Inspector and Access Analyzer
      "inspector2:Disable",
      "inspector2:DisassociateMember",
      "access-analyzer:DeleteAnalyzer",
      # Account-wide encryption and public access guardrails
      "ec2:DisableEbsEncryptionByDefault",
      "s3:PutAccountPublicAccessBlock",
      # Password policy
      "iam:DeleteAccountPasswordPolicy",
      "iam:UpdateAccountPasswordPolicy",
      # KMS key destruction
      "kms:DisableKey",
      "kms:ScheduleKeyDeletion",
    ]
    resources = ["*"]

    dynamic "condition" {
      for_each = local.has_admin_exemption ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.security_admin_role_arns
      }
    }
  }
}

# SCP 4: deny API calls outside the allowed regions, except for global
# services
# (SC-7 authorization boundary, CM-7 least functionality).
data "aws_iam_policy_document" "deny_regions" {
  statement {
    sid    = "DenyAllOutsideAllowedRegions"
    effect = "Deny"
    not_actions = [
      "access-analyzer:*",
      "account:*",
      "acm:*",
      "artifact:*",
      "aws-marketplace-management:*",
      "aws-marketplace:*",
      "aws-portal:*",
      "billing:*",
      "billingconductor:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "cloudfront-keyvaluestore:*",
      "consolidatedbilling:*",
      "cur:*",
      "directconnect:*",
      "ec2:DescribeRegions",
      "ec2:DescribeTransitGateways",
      "ec2:DescribeVpnGateways",
      "freetier:*",
      "globalaccelerator:*",
      "health:*",
      "iam:*",
      "invoicing:*",
      "networkmanager:*",
      "notifications:*",
      "notifications-contacts:*",
      "organizations:*",
      "payments:*",
      "pricing:*",
      "resource-explorer-2:*",
      "route53:*",
      "route53-recovery-cluster:*",
      "route53-recovery-control-config:*",
      "route53-recovery-readiness:*",
      "route53domains:*",
      "s3:CreateMultiRegionAccessPoint",
      "s3:DeleteMultiRegionAccessPoint",
      "s3:DescribeMultiRegionAccessPointOperation",
      "s3:GetAccountPublicAccessBlock",
      "s3:GetBucketLocation",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetMultiRegionAccessPoint",
      "s3:GetMultiRegionAccessPointPolicy",
      "s3:GetMultiRegionAccessPointPolicyStatus",
      "s3:GetStorageLensConfiguration",
      "s3:GetStorageLensDashboard",
      "s3:ListAllMyBuckets",
      "s3:ListMultiRegionAccessPoints",
      "s3:ListStorageLensConfigurations",
      "s3:PutAccountPublicAccessBlock",
      "s3:PutMultiRegionAccessPointPolicy",
      "savingsplans:*",
      "shield:*",
      "sso:*",
      "sts:*",
      "support:*",
      "supportapp:*",
      "supportplans:*",
      "sustainability:*",
      "tag:*",
      "tax:*",
      "trustedadvisor:*",
      "waf-regional:*",
      "waf:*",
      "wafv2:*",
      "wellarchitected:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }

    dynamic "condition" {
      for_each = local.has_admin_exemption ? [1] : []
      content {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.security_admin_role_arns
      }
    }
  }
}

# SCP 5: EC2 instances must use IMDSv2 (SC-7, CM-6, protects against SSRF
# credential theft).
data "aws_iam_policy_document" "require_imdsv2" {
  statement {
    sid       = "RequireImdsV2OnLaunch"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:*:*:instance/*"]

    condition {
      test     = "StringNotEquals"
      variable = "ec2:MetadataHttpTokens"
      values   = ["required"]
    }
  }

  statement {
    sid       = "DenyImdsHopLimitAboveOne"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:*:*:instance/*"]

    condition {
      test     = "NumericGreaterThan"
      variable = "ec2:MetadataHttpPutResponseHopLimit"
      values   = ["1"]
    }
  }

  dynamic "statement" {
    for_each = local.has_admin_exemption ? [1] : []
    content {
      sid       = "DenyImdsDowngradeExceptAdmins"
      effect    = "Deny"
      actions   = ["ec2:ModifyInstanceMetadataOptions"]
      resources = ["*"]

      condition {
        test     = "ArnNotLike"
        variable = "aws:PrincipalArn"
        values   = var.security_admin_role_arns
      }
    }
  }
}

locals {
  scps = {
    deny-leave-organization   = { description = "Prevents member accounts from leaving the organization (CM-3).", document = data.aws_iam_policy_document.deny_leave_org }
    deny-root-user            = { description = "Denies all actions by the root user in member accounts (AC-6(5)).", document = data.aws_iam_policy_document.deny_root_user }
    protect-security-services = { description = "Prevents disabling CloudTrail, GuardDuty, Security Hub, Config, Inspector and encryption defaults (AU-9, SI-4).", document = data.aws_iam_policy_document.protect_security_services }
    deny-regions-outside-us   = { description = "Restricts API calls to the authorized regions (SC-7, CM-7).", document = data.aws_iam_policy_document.deny_regions }
    require-imdsv2            = { description = "Requires IMDSv2 on EC2 launches (SC-7, CM-6).", document = data.aws_iam_policy_document.require_imdsv2 }
  }

  # Attach every SCP to every OU. Accounts land in OUs, never directly under
  # root.
  scp_attachments = {
    for pair in setproduct(keys(local.scps), var.organizational_units) :
    "${pair[0]}/${pair[1]}" => { scp = pair[0], ou = pair[1] }
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.document.minified_json

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "scp" {
  for_each = local.scp_attachments

  policy_id = aws_organizations_policy.scp[each.value.scp].id
  target_id = aws_organizations_organizational_unit.this[each.value.ou].id
}
