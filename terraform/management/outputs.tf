output "organization_trail_arn" {
  value = aws_cloudtrail.organization.arn
}

output "organization_id" {
  value = data.aws_organizations_organization.this.id
}

output "management_account_id" {
  value = data.aws_organizations_organization.this.master_account_id
}
