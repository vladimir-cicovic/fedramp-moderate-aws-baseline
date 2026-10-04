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

variable "is_organization_trail" {
  description = "Create an organization trail (requires management account and CloudTrail trusted access)."
  type        = bool
  default     = false
}

variable "organization_id" {
  description = "Organization ID, required for the org trail bucket policy."
  type        = string
  default     = null
}

variable "allow_management_trail" {
  description = "Admit an organization trail owned by the management account (same trail name) into this account's bucket, KMS key and CloudWatch Logs role. Used when the organization trail is created from terraform/management while this account owns the log storage."
  type        = bool
  default     = false
}

variable "management_trail_name" {
  description = "Name of the management account's organization trail admitted into this account's log storage. Defaults to this account's trail name."
  type        = string
  default     = null
}

variable "management_account_id" {
  description = "Management account ID. CloudTrail validates organization trails against a trail ARN and log path owned by the management account, even when a delegated administrator creates the trail."
  type        = string
  default     = null
}

variable "object_lock_mode" {
  type = string
}

variable "object_lock_days" {
  type = number
}

variable "log_expiration_days" {
  type = number
}

variable "cloudwatch_log_retention_days" {
  type = number
}

variable "enable_s3_data_events" {
  type = bool
}

variable "alert_email" {
  type    = string
  default = null
}

variable "kms_deletion_window_in_days" {
  type = number
}
