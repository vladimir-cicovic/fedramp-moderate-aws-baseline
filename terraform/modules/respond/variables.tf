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
  description = "SNS topic that receives the containment report."
  type        = string
}

variable "alerts_kms_key_arn" {
  description = "KMS key encrypting the alerts topic (the function needs GenerateDataKey on it)."
  type        = string
}

variable "logging_kms_key_arn" {
  description = "KMS key for the function's log group and dead-letter queue."
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 400
}

variable "quarantine_security_group_ids" {
  description = "Quarantine security groups keyed by VPC ID. An isolated EC2 instance gets the one from its VPC."
  type        = map(string)
  default     = {}
}

variable "dry_run" {
  description = "Log and notify what would be done without changing anything."
  type        = bool
  default     = false
}

variable "minimum_severity" {
  description = "GuardDuty severity at or above which containment runs (7 = High)."
  type        = number
  default     = 7
}
