output "organization_id" {
  value = local.organization_id
}

output "root_id" {
  value = local.root_id
}

output "management_account_id" {
  value = local.management_account_id
}

output "organizational_unit_ids" {
  value = { for k, ou in aws_organizations_organizational_unit.this : k => ou.id }
}

output "scp_ids" {
  value = { for k, p in aws_organizations_policy.scp : k => p.id }
}
