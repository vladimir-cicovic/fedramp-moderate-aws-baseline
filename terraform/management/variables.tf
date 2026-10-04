variable "aws_profile" {
  description = "AWS CLI profile with management-account credentials."
  type        = string
  default     = "mgmt"
}

variable "region" {
  description = "Home region of the organization trail. Must match the region of the log bucket's account deployment."
  type        = string
  default     = "us-east-1"
}

variable "use_fips_endpoints" {
  description = "Call FIPS 140 validated API endpoints (SC-13)."
  type        = bool
  default     = true
}

variable "project" {
  type    = string
  default = "fedramp-baseline"
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "trail_name" {
  description = "Organization trail name. Must match management_trail_name in the Security Tooling account (default <project>-<environment>-org-trail) so that account's bucket and KMS policies admit it."
  type        = string
  default     = "fedramp-baseline-lab-org-trail"
}

variable "log_bucket_name" {
  description = "CloudTrail bucket owned by the Security Tooling account (output logging.cloudtrail_bucket of the main root)."
  type        = string
}

variable "logging_kms_key_arn" {
  description = "Logging KMS key owned by the Security Tooling account (output logging.logging_kms_key_arn of the main root)."
  type        = string
}
