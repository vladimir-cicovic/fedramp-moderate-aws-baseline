data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Organization identity when this account is a delegated administrator rather
# than the management account (organization trail, organization aggregator).
data "aws_organizations_organization" "current" {
  count = (var.enable_organization_trail || var.enable_config_aggregator) && !var.enable_organizations ? 1 : 0
}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  name_prefix = "${var.project}-${var.environment}"

  organization_trail = var.enable_organizations || var.enable_organization_trail
  config_aggregator  = var.enable_organizations || var.enable_config_aggregator
  organization_id = (
    var.enable_organizations ? module.org[0].organization_id :
    (local.organization_trail || local.config_aggregator) ? data.aws_organizations_organization.current[0].id : null
  )
  management_account_id = (
    var.enable_organizations ? module.org[0].management_account_id :
    (local.organization_trail || local.config_aggregator) ? data.aws_organizations_organization.current[0].master_account_id : null
  )

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "github.com/${var.github_org}/${var.github_repo}"
    Compliance  = "NIST-800-53-R5-Moderate"
  }
}

# Day 1: foundation

# AWS Organizations: OUs and Service Control Policies.
# Controls: AC-6, CM-7, SC-7, AU-9 (protect logging from being disabled).
module "org" {
  count  = var.enable_organizations ? 1 : 0
  source = "./modules/org"

  create_organization      = var.create_organization
  allowed_regions          = var.allowed_regions
  security_admin_role_arns = var.security_admin_role_arns
}

# Identity: password policy, GitHub OIDC (no long-lived keys), Identity
# Center.
# Controls: AC-2, AC-3, AC-6, IA-2, IA-5.
module "identity" {
  source = "./modules/identity"
  providers = {
    aws = aws.sso
  }

  name_prefix            = local.name_prefix
  account_id             = local.account_id
  partition              = local.partition
  github_org             = var.github_org
  github_repo            = var.github_repo
  enable_identity_center = var.enable_identity_center
}

# Logging: CloudTrail (org trail), immutable S3, CloudWatch alarms, AWS Config
# recorder.
# Controls: AU-2, AU-3, AU-6, AU-8, AU-9, AU-11, AU-12, SI-4, CM-8.
module "logging" {
  source = "./modules/logging"

  name_prefix = local.name_prefix
  account_id  = local.account_id
  partition   = local.partition
  region      = var.region
  # This account's own trail is an organization trail only when run from the
  # management account.
  is_organization_trail         = var.enable_organizations
  allow_management_trail        = var.enable_organization_trail
  management_trail_name         = "${local.name_prefix}-org-trail"
  organization_id               = local.organization_id
  management_account_id         = local.management_account_id
  object_lock_mode              = var.object_lock_mode
  object_lock_days              = var.object_lock_days
  log_expiration_days           = var.log_expiration_days
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days
  enable_s3_data_events         = var.enable_s3_data_events
  alert_email                   = var.alert_email
  kms_deletion_window_in_days   = var.kms_deletion_window_in_days

  depends_on = [module.org]
}

# Day 2: detection

# GuardDuty, Security Hub (NIST 800-53 R5, NIST 800-171 R2, FSBP), Inspector,
# Config conformance pack, IAM Access Analyzer, finding notifications.
module "detection" {
  source = "./modules/detection"

  name_prefix               = local.name_prefix
  account_id                = local.account_id
  partition                 = local.partition
  region                    = var.region
  security_alerts_topic_arn = module.logging.security_alerts_topic_arn

  security_hub_standards        = var.security_hub_standards
  inspector_resource_types      = var.inspector_resource_types
  enable_conformance_pack       = var.enable_conformance_pack
  enable_unused_access_analyzer = var.enable_unused_access_analyzer
  unused_access_age             = var.unused_access_age
  enable_config_aggregator      = local.config_aggregator

  # Security Hub and the conformance pack need the Config recorder running.
  depends_on = [module.logging]
}

# Cryptography baseline: customer-managed data key, EBS encryption by default,
# account-wide S3 public access block.
module "crypto" {
  source = "./modules/crypto"

  name_prefix                 = local.name_prefix
  account_id                  = local.account_id
  partition                   = local.partition
  kms_deletion_window_in_days = var.kms_deletion_window_in_days
  key_administrator_arns      = var.kms_key_administrator_arns
  key_user_arns               = var.kms_key_user_arns
}

# Day 3: boundary, edge, data, response

# VPC with public / private / data tiers, deny-by-default NACLs, FIPS
# interface
# endpoints, no NAT, flow logs, quarantine security group.
module "network" {
  count  = var.enable_network ? 1 : 0
  source = "./modules/network"

  name_prefix               = local.name_prefix
  account_id                = local.account_id
  partition                 = local.partition
  region                    = var.region
  vpc_cidr                  = var.vpc_cidr
  az_count                  = var.az_count
  enable_vpc_endpoints      = var.enable_vpc_endpoints
  vpc_endpoint_subnet_count = var.vpc_endpoint_subnet_count
  flow_logs_kms_key_arn     = module.logging.logging_kms_key_arn
  flow_log_retention_days   = var.cloudwatch_log_retention_days
}

# CloudFront + WAFv2 + OAC in front of a private S3 origin, security headers,
# access and WAF logs to encrypted CloudWatch Logs.
module "edge" {
  count  = var.enable_edge ? 1 : 0
  source = "./modules/edge"

  name_prefix         = local.name_prefix
  account_id          = local.account_id
  partition           = local.partition
  region              = var.region
  logging_kms_key_arn = module.logging.logging_kms_key_arn
  log_retention_days  = var.cloudwatch_log_retention_days
  waf_rate_limit      = var.waf_rate_limit
  acm_certificate_arn = var.acm_certificate_arn
  aliases             = var.cloudfront_aliases
}

# Aurora MySQL Serverless v2 in the data tier: TLS required, IAM auth, CMK
# encryption, audit logs, RDS-managed secret, scales to zero.
module "data" {
  count  = var.enable_network && var.enable_database ? 1 : 0
  source = "./modules/data"

  name_prefix           = local.name_prefix
  vpc_id                = module.network[0].vpc_id
  subnet_ids            = module.network[0].data_subnet_ids
  allowed_cidrs         = module.network[0].private_subnet_cidrs
  kms_key_arn           = module.crypto.data_kms_key_arn
  logging_kms_key_arn   = module.logging.logging_kms_key_arn
  log_retention_days    = var.cloudwatch_log_retention_days
  backup_retention_days = var.aurora_backup_retention_days
  deletion_protection   = var.aurora_deletion_protection
  skip_final_snapshot   = !var.aurora_deletion_protection
}

# Automated containment: GuardDuty High/Critical on IAM keys or EC2 instances
# -> Lambda deactivates the key / isolates the instance, reports to the topic.
module "respond" {
  count  = var.enable_respond ? 1 : 0
  source = "./modules/respond"

  name_prefix               = local.name_prefix
  account_id                = local.account_id
  partition                 = local.partition
  region                    = var.region
  security_alerts_topic_arn = module.logging.security_alerts_topic_arn
  alerts_kms_key_arn        = module.logging.alerts_kms_key_arn
  logging_kms_key_arn       = module.logging.logging_kms_key_arn
  log_retention_days        = var.cloudwatch_log_retention_days
  dry_run                   = var.containment_dry_run
  quarantine_security_group_ids = var.enable_network ? {
    (module.network[0].vpc_id) = module.network[0].quarantine_security_group_id
  } : {}
}
