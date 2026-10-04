variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "partition" {
  type = string
}

variable "region" {
  type = string
}

variable "security_alerts_topic_arn" {
  description = "SNS topic that receives high-severity findings."
  type        = string
}

variable "security_hub_standards" {
  description = "Security Hub standards to enable, as the path part of the standards ARN."
  type        = list(string)
  default = [
    "nist-800-53/v/5.0.0",
    "nist-800-171/v/2.0.0",
    "aws-foundational-security-best-practices/v/1.0.0",
  ]
}

variable "inspector_resource_types" {
  description = "Inspector scan targets."
  type        = list(string)
  default     = ["EC2", "ECR", "LAMBDA"]
}

variable "enable_conformance_pack" {
  description = "Deploy the AWS Config conformance pack 'Operational Best Practices for NIST 800-53 Rev 5'."
  type        = bool
  default     = true
}

variable "enable_unused_access_analyzer" {
  description = "Enable the IAM Access Analyzer unused-access analyzer (small per-role monthly charge)."
  type        = bool
  default     = true
}

variable "unused_access_age" {
  description = "Days of inactivity before a role, user, permission or key is reported as unused (AC-2(3))."
  type        = number
  default     = 90
}

variable "enable_config_aggregator" {
  description = "Create an organization-wide Config aggregator (account must be Config delegated administrator or management)."
  type        = bool
  default     = false
}

variable "password_policy" {
  description = "Values the conformance pack IAM_PASSWORD_POLICY rule checks against. Must match the identity module."
  type = object({
    minimum_password_length   = number
    max_password_age          = number
    password_reuse_prevention = number
  })
  default = {
    minimum_password_length   = 14
    max_password_age          = 60
    password_reuse_prevention = 24
  }
}
