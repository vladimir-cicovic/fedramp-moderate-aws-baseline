variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "partition" {
  type = string
}

variable "kms_deletion_window_in_days" {
  type = number
}

variable "key_administrator_arns" {
  description = "Principals that administer the data key but cannot use it for cryptographic operations."
  type        = list(string)
  default     = []
}

variable "key_user_arns" {
  description = "Principals that can use the data key but cannot administer it."
  type        = list(string)
  default     = []
}
