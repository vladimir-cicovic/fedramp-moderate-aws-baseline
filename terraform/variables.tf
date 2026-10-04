# General

variable "region" {
  description = "Primary AWS region. Production FedRAMP boundary: a US commercial region (FIPS 140 endpoints exist only there). The lab may run elsewhere; see output fips_endpoints_available."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use. Null uses the default credential chain (env vars, default profile, SSO)."
  type        = string
  default     = null
}

variable "use_fips_endpoints" {
  description = "Make the provider call FIPS 140 validated API endpoints (SC-13). Only available in US and Canada regions."
  type        = bool
  default     = false
}

variable "project" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "fedramp-baseline"
}

variable "environment" {
  description = "Environment name (lab, dev, prod)."
  type        = string
  default     = "lab"
}

variable "allowed_regions" {
  description = "Regions in which workloads may run. Everything else is denied by SCP (SC-7, CM-7)."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# AWS Organizations

variable "enable_organizations" {
  description = "Manage AWS Organizations (OUs, SCPs) and create an organization trail. Requires the management account."
  type        = bool
  default     = true
}

variable "create_organization" {
  description = "Create the organization. Set to false if this account is already the management account of an existing organization."
  type        = bool
  default     = true
}

variable "enable_organization_trail" {
  description = "This account stores the organization trail's logs: its bucket, KMS key and CloudWatch Logs role admit the management account's trail. The trail itself is created with terraform/management (organization trails are always owned by the management account; the AWS provider cannot manage one from a delegated administrator)."
  type        = bool
  default     = false
}

variable "enable_config_aggregator" {
  description = "Create an organization-wide AWS Config aggregator (requires Config delegated admin registration). Implied by enable_organizations."
  type        = bool
  default     = false
}

variable "security_admin_role_arns" {
  description = "Principal ARN patterns exempt from protective SCPs (ArnNotLike). Defaults to the Identity Center SecurityAdmin permission set role."
  type        = list(string)
  default     = ["arn:aws:iam::*:role/aws-reserved/sso.amazonaws.com/*/AWSReservedSSO_SecurityAdmin_*"]
}

# Identity

variable "enable_identity_center" {
  description = "Manage IAM Identity Center permission sets, groups and assignments. Identity Center itself must be enabled in the console first."
  type        = bool
  default     = false
}

variable "identity_center_region" {
  description = "Region where IAM Identity Center was enabled. Defaults to var.region."
  type        = string
  default     = null
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository (OIDC trust)."
  type        = string
  default     = "vladimir-cicovic"
}

variable "github_repo" {
  description = "GitHub repository name (OIDC trust)."
  type        = string
  default     = "fedramp-moderate-aws-baseline"
}

# Logging and retention

variable "object_lock_mode" {
  description = "S3 Object Lock mode for the CloudTrail bucket. COMPLIANCE for production (nobody can delete, not even root). GOVERNANCE for the lab so it can be torn down."
  type        = string
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE."
  }
}

variable "object_lock_days" {
  description = "Default Object Lock retention in days for audit logs. FedRAMP AU-11: 1 year total retention; use 365+ in production."
  type        = number
  default     = 1
}

variable "log_expiration_days" {
  description = "S3 lifecycle expiration for audit logs. 400 keeps a little over one year (AU-11)."
  type        = number
  default     = 400
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch Logs retention for the CloudTrail log group."
  type        = number
  default     = 400
}

variable "enable_s3_data_events" {
  description = "Log S3 object-level data events in CloudTrail (AU-2, AU-12). Small cost in a lab."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address subscribed to the security alerts SNS topic. Null to skip the subscription."
  type        = string
  default     = null
}

# Detection

variable "security_hub_standards" {
  description = "Security Hub standards to enable (path part of the standards ARN)."
  type        = list(string)
  default = [
    "nist-800-53/v/5.0.0",
    "nist-800-171/v/2.0.0",
    "aws-foundational-security-best-practices/v/1.0.0",
  ]
}

variable "inspector_resource_types" {
  description = "Amazon Inspector scan targets."
  type        = list(string)
  default     = ["EC2", "ECR", "LAMBDA"]
}

variable "enable_conformance_pack" {
  description = "Deploy the AWS Config conformance pack for NIST 800-53 Rev 5 (130 managed rules)."
  type        = bool
  default     = true
}

variable "enable_unused_access_analyzer" {
  description = "Enable the IAM Access Analyzer unused-access analyzer (about 0.20 USD per role per month)."
  type        = bool
  default     = true
}

variable "unused_access_age" {
  description = "Days of inactivity before access is reported as unused (AC-2(3))."
  type        = number
  default     = 90
}

# Day 3: network, edge, data, response

variable "enable_network" {
  description = "Create the VPC (tiers, NACLs, endpoints, flow logs, quarantine SG)."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "enable_vpc_endpoints" {
  description = "Interface endpoints for KMS, Secrets Manager, STS and Logs (FIPS variants). About 0.01 USD per hour each."
  type        = bool
  default     = true
}

variable "vpc_endpoint_subnet_count" {
  description = "AZs per interface endpoint. 1 in the lab, az_count in production."
  type        = number
  default     = 1
}

variable "enable_edge" {
  description = "Create CloudFront + WAFv2 with a private S3 origin."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

variable "acm_certificate_arn" {
  description = "ACM certificate (us-east-1) for a custom CloudFront domain. Enables TLS 1.2 minimum."
  type        = string
  default     = null
}

variable "cloudfront_aliases" {
  type    = list(string)
  default = []
}

variable "enable_database" {
  description = "Create the Aurora MySQL Serverless v2 cluster in the data tier (requires enable_network)."
  type        = bool
  default     = false
}

variable "aurora_backup_retention_days" {
  type    = number
  default = 7
}

variable "aurora_deletion_protection" {
  description = "Off in the lab so terraform destroy works; on in production."
  type        = bool
  default     = false
}

variable "enable_respond" {
  description = "Create the GuardDuty containment Lambda and its EventBridge trigger."
  type        = bool
  default     = true
}

variable "containment_dry_run" {
  description = "Containment Lambda only reports what it would do."
  type        = bool
  default     = false
}

# Cryptography

variable "kms_deletion_window_in_days" {
  description = "Waiting period before a scheduled KMS key deletion. 7 for the lab, 30 for production."
  type        = number
  default     = 7
}

variable "kms_key_administrator_arns" {
  description = "IAM principals allowed to administer (but not use) the data KMS key. Separation of duties (AC-5, SC-12)."
  type        = list(string)
  default     = []
}

variable "kms_key_user_arns" {
  description = "IAM principals allowed to use (but not administer) the data KMS key."
  type        = list(string)
  default     = []
}
