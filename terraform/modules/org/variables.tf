variable "create_organization" {
  description = "Create the organization (true) or read an existing one (false)."
  type        = bool
  default     = true
}

variable "allowed_regions" {
  description = "Regions where non-global API calls are allowed."
  type        = list(string)
}

variable "security_admin_role_arns" {
  description = "Principal ARN patterns exempt from protective SCPs."
  type        = list(string)
  default     = []
}

variable "organizational_units" {
  description = "Top-level OUs to create under the root."
  type        = list(string)
  default     = ["Security", "Workloads", "Sandbox"]
}
