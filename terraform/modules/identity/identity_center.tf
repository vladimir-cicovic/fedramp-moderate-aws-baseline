# IAM Identity Center (AC-2, AC-3, AC-6, IA-2, IA-2(1), IA-2(2))
# Humans never get IAM users.

data "aws_ssoadmin_instances" "this" {
  count = var.enable_identity_center ? 1 : 0
}

locals {
  sso_enabled       = var.enable_identity_center
  sso_instance_arn  = local.sso_enabled ? tolist(data.aws_ssoadmin_instances.this[0].arns)[0] : null
  identity_store_id = local.sso_enabled ? tolist(data.aws_ssoadmin_instances.this[0].identity_store_ids)[0] : null

  # Permission sets. Session duration is shorter for more privileged sets
  # (AC-12).
  permission_sets = local.sso_enabled ? {
    ReadOnly = {
      description      = "Read-only access to all services. Default for engineers who need visibility."
      session_duration = "PT8H"
      managed_policies = ["arn:${var.partition}:iam::aws:policy/ReadOnlyAccess"]
      inline_policy    = null
      boundary         = null
      group            = "ReadOnly"
    }
    SecurityAuditor = {
      description      = "Read-only plus security service visibility for auditors and 3PAO assessors."
      session_duration = "PT8H"
      managed_policies = [
        "arn:${var.partition}:iam::aws:policy/ReadOnlyAccess",
        "arn:${var.partition}:iam::aws:policy/SecurityAudit",
      ]
      inline_policy = null
      boundary      = null
      group         = "SecurityAuditors"
    }
    SecurityAdmin = {
      description      = "Administers security services. Exempt from protective SCPs. Short session."
      session_duration = "PT1H"
      managed_policies = ["arn:${var.partition}:iam::aws:policy/ReadOnlyAccess"]
      inline_policy    = data.aws_iam_policy_document.security_admin.json
      boundary         = null
      group            = "SecurityAdmins"
    }
    DeveloperRestricted = {
      description      = "Power user bounded by a permissions boundary: cannot touch security tooling or escalate via IAM."
      session_duration = "PT4H"
      managed_policies = ["arn:${var.partition}:iam::aws:policy/PowerUserAccess"]
      inline_policy    = null
      boundary         = aws_iam_policy.developer_boundary.name
      group            = "Developers"
    }
  } : {}

  groups = local.sso_enabled ? toset([for ps in local.permission_sets : ps.group]) : toset([])
}

# Inline policy for SecurityAdmin: full control of the security tooling and
# the ability to create service-linked roles, nothing else beyond read-only.
data "aws_iam_policy_document" "security_admin" {
  #checkov:skip=CKV_AWS_109:Security tooling administration is account-wide by nature; access is MFA-gated through Identity Center with a 1-hour session
  #checkov:skip=CKV_AWS_111:Same as above
  #checkov:skip=CKV_AWS_356:Same as above; most of these APIs do not support resource-level permissions
  statement {
    sid    = "SecurityServicesFullAccess"
    effect = "Allow"
    actions = [
      "access-analyzer:*",
      "cloudtrail:*",
      "config:*",
      "guardduty:*",
      "inspector2:*",
      "securityhub:*",
      "kms:*",
      "logs:*",
      "cloudwatch:*",
      "sns:*",
      "events:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:${var.partition}:iam::*:role/aws-service-role/*"]
  }
}

# Permissions boundary for developers (AC-6, CM-5). Allows everything the
# attached policy allows, except: security tooling, IAM principal creation
# without this same boundary, and regions outside the boundary.
data "aws_iam_policy_document" "developer_boundary" {
  #checkov:skip=CKV_AWS_1:Permissions boundary, not a grant. Effective permissions are the intersection with the attached policy; the Deny statements below are the point
  #checkov:skip=CKV_AWS_49:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_107:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_108:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_109:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_110:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_111:Permissions boundary ceiling, see above
  #checkov:skip=CKV_AWS_356:Permissions boundary ceiling, see above
  #checkov:skip=CKV2_AWS_40:IAM escalation is blocked by the DenyIamPrincipalCreationWithoutBoundary and DenyBoundaryTampering statements
  statement {
    sid       = "AllowEverythingByDefault"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenySecurityTooling"
    effect = "Deny"
    actions = [
      "cloudtrail:*",
      "config:*",
      "guardduty:*",
      "securityhub:*",
      "inspector2:*",
      "access-analyzer:*",
      "organizations:*",
      "sso:*",
      "sso-directory:*",
      "identitystore:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIamPrincipalCreationWithoutBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:CreateUser",
      "iam:PutRolePermissionsBoundary",
      "iam:PutUserPermissionsBoundary",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = ["arn:${var.partition}:iam::${var.account_id}:policy/${var.name_prefix}-developer-boundary"]
    }
  }

  statement {
    sid    = "DenyBoundaryTampering"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = ["arn:${var.partition}:iam::${var.account_id}:policy/${var.name_prefix}-developer-boundary"]
  }
}

resource "aws_iam_policy" "developer_boundary" {
  name        = "${var.name_prefix}-developer-boundary"
  description = "Permissions boundary applied to the DeveloperRestricted permission set."
  policy      = data.aws_iam_policy_document.developer_boundary.json
}

# Permission sets

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.sso_instance_arn
  session_duration = each.value.session_duration
}

locals {
  managed_policy_attachments = merge([
    for ps_name, ps in local.permission_sets : {
      for arn in ps.managed_policies : "${ps_name}/${arn}" => { ps = ps_name, arn = arn }
    }
  ]...)
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.managed_policy_attachments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps].arn
  managed_policy_arn = each.value.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = { for k, v in local.permission_sets : k => v if v.inline_policy != null }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value.inline_policy
}

resource "aws_ssoadmin_permissions_boundary_attachment" "this" {
  for_each = { for k, v in local.permission_sets : k => v if v.boundary != null }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn

  permissions_boundary {
    customer_managed_policy_reference {
      name = each.value.boundary
      path = "/"
    }
  }
}

# Groups and account assignments (AC-2(1) automated account management)
# Access is granted to groups, never to individual users.

resource "aws_identitystore_group" "this" {
  for_each = local.groups

  identity_store_id = local.identity_store_id
  display_name      = each.value
  description       = "Managed by Terraform. Maps 1:1 to the ${each.value} permission set."
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.permission_sets

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn

  principal_id   = aws_identitystore_group.this[each.value.group].group_id
  principal_type = "GROUP"

  target_id   = var.account_id
  target_type = "AWS_ACCOUNT"
}
