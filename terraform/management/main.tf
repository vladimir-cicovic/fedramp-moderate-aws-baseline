# Management account root
# The only things that must run with management-account credentials: - the
# organization trail (always owned by the management account) - SCPs and OUs.

provider "aws" {
  region            = var.region
  profile           = var.aws_profile
  use_fips_endpoint = var.use_fips_endpoints

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Scope       = "management-account"
      Compliance  = "NIST-800-53-R5-Moderate"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "this" {}

locals {
  is_management_account = data.aws_caller_identity.current.account_id == data.aws_organizations_organization.this.master_account_id
}

# Organization trail: management events for every account in the organization,
# multi-region, integrity-validated, encrypted with the Security Tooling
# account's key, delivered to the Security Tooling account's WORM bucket.
resource "aws_cloudtrail" "organization" {
  #checkov:skip=CKV_AWS_252:Per-file delivery notifications are not wanted; integrity is covered by log file validation digests
  #checkov:skip=CKV2_AWS_10:CloudTrail cannot stream to a CloudWatch Logs group in another account; near-real-time alerting runs on the Security Tooling account's own trail
  name                          = var.trail_name
  s3_bucket_name                = var.log_bucket_name
  kms_key_id                    = var.logging_kms_key_arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true

  advanced_event_selector {
    name = "All management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  lifecycle {
    precondition {
      condition     = local.is_management_account
      error_message = "Profile '${var.aws_profile}' is not the management account of ${data.aws_organizations_organization.this.id}. Organization trails can only be created there."
    }
  }
}
