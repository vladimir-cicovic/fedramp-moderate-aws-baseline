output "account_id" {
  description = "AWS account ID the baseline is deployed into."
  value       = local.account_id
}

output "fips_endpoints_available" {
  description = "Whether the deployment region offers FIPS 140 validated API endpoints (SC-13). Production must be true."
  value       = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "ca-west-1"], var.region)
}

output "organization" {
  description = "AWS Organizations identifiers (null when enable_organizations = false)."
  value = var.enable_organizations ? {
    organization_id          = module.org[0].organization_id
    root_id                  = module.org[0].root_id
    management_account_id    = module.org[0].management_account_id
    organizational_units     = module.org[0].organizational_unit_ids
    service_control_policies = module.org[0].scp_ids
  } : null
}

output "identity" {
  description = "Identity resources: GitHub OIDC roles and Identity Center permission sets."
  value = {
    github_oidc_provider_arn = module.identity.github_oidc_provider_arn
    github_plan_role_arn     = module.identity.github_plan_role_arn
    github_evidence_role_arn = module.identity.github_evidence_role_arn
    permission_set_arns      = module.identity.permission_set_arns
    identity_center_instance = module.identity.identity_center_instance_arn
  }
}

output "logging" {
  description = "Audit logging resources."
  value = {
    cloudtrail_arn            = module.logging.cloudtrail_arn
    cloudtrail_bucket         = module.logging.cloudtrail_bucket_name
    config_bucket             = module.logging.config_bucket_name
    access_logs_bucket        = module.logging.access_logs_bucket_name
    cloudtrail_log_group      = module.logging.cloudtrail_log_group_name
    logging_kms_key_arn       = module.logging.logging_kms_key_arn
    alerts_kms_key_arn        = module.logging.alerts_kms_key_arn
    security_alerts_topic_arn = module.logging.security_alerts_topic_arn
    config_recorder_name      = module.logging.config_recorder_name
  }
}

output "detection" {
  description = "Detection and continuous monitoring resources."
  value = {
    guardduty_detector_id    = module.detection.guardduty_detector_id
    security_hub_arn         = module.detection.security_hub_arn
    security_hub_standards   = module.detection.security_hub_standards
    inspector_resource_types = module.detection.inspector_resource_types
    conformance_pack_arn     = module.detection.conformance_pack_arn
    config_aggregator_arn    = module.detection.config_aggregator_arn
    access_analyzer_arns     = module.detection.access_analyzer_arns
    event_rules              = module.detection.event_rules
  }
}

output "network" {
  description = "VPC and subnet identifiers."
  value = var.enable_network ? {
    vpc_id                       = module.network[0].vpc_id
    vpc_cidr                     = module.network[0].vpc_cidr
    availability_zones           = module.network[0].availability_zones
    public_subnet_ids            = module.network[0].public_subnet_ids
    private_subnet_ids           = module.network[0].private_subnet_ids
    data_subnet_ids              = module.network[0].data_subnet_ids
    quarantine_security_group_id = module.network[0].quarantine_security_group_id
    interface_endpoint_ids       = module.network[0].interface_endpoint_ids
    flow_log_group_name          = module.network[0].flow_log_group_name
  } : null
}

output "edge" {
  description = "CloudFront distribution and WAF."
  value = var.enable_edge ? {
    distribution_id          = module.edge[0].distribution_id
    distribution_domain_name = module.edge[0].distribution_domain_name
    web_acl_arn              = module.edge[0].web_acl_arn
    origin_bucket_name       = module.edge[0].origin_bucket_name
    waf_log_group_name       = module.edge[0].waf_log_group_name
    access_log_group_name    = module.edge[0].access_log_group_name
  } : null
}

output "data" {
  description = "Aurora cluster."
  value = var.enable_network && var.enable_database ? {
    cluster_arn            = module.data[0].cluster_arn
    cluster_endpoint       = module.data[0].cluster_endpoint
    reader_endpoint        = module.data[0].reader_endpoint
    master_user_secret_arn = module.data[0].master_user_secret_arn
  } : null
}

output "respond" {
  description = "GuardDuty containment function."
  value = var.enable_respond ? {
    function_name         = module.respond[0].function_name
    function_arn          = module.respond[0].function_arn
    event_rule_arn        = module.respond[0].event_rule_arn
    dead_letter_queue_arn = module.respond[0].dead_letter_queue_arn
  } : null
}

output "crypto" {
  description = "Cryptography baseline resources."
  value = {
    data_kms_key_arn   = module.crypto.data_kms_key_arn
    data_kms_key_alias = module.crypto.data_kms_key_alias
  }
}
