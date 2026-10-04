variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Data-tier subnets."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the database port (the private application subnets)."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Customer managed key for storage, the managed master secret and Performance Insights."
  type        = string
}

variable "logging_kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 400
}

variable "engine_version" {
  description = "Aurora MySQL version. 3.08+ is required for Serverless v2 scaling to zero."
  type        = string
  default     = "8.0.mysql_aurora.3.13.0"
}

variable "min_capacity" {
  description = "Serverless v2 minimum ACU. 0 pauses the cluster when idle."
  type        = number
  default     = 0
}

variable "max_capacity" {
  type    = number
  default = 1
}

variable "backup_retention_days" {
  description = "Automated backup retention (CP-9). FedRAMP expects backups; 7 days in the lab, 35 in production."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}
