output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_plan_role_arn" {
  value = aws_iam_role.github_plan.arn
}

output "github_evidence_role_arn" {
  value = aws_iam_role.github_evidence.arn
}

output "developer_boundary_policy_arn" {
  value = aws_iam_policy.developer_boundary.arn
}

output "identity_center_instance_arn" {
  value = local.sso_instance_arn
}

output "permission_set_arns" {
  value = { for k, ps in aws_ssoadmin_permission_set.this : k => ps.arn }
}

output "group_ids" {
  value = { for k, g in aws_identitystore_group.this : k => g.group_id }
}
