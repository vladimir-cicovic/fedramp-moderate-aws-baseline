variable "name_prefix" {
  type = string
}

variable "account_id" {
  type = string
}

variable "partition" {
  type = string
}

variable "github_org" {
  description = "GitHub organization or user trusted by the OIDC roles."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository trusted by the OIDC roles."
  type        = string
}

variable "enable_identity_center" {
  description = "Manage Identity Center permission sets, groups and assignments."
  type        = bool
  default     = false
}

variable "password_policy" {
  description = "IAM account password policy (IA-5). Defaults follow the FedRAMP Moderate parameter values."
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
