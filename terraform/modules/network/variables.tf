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

variable "vpc_cidr" {
  description = "VPC CIDR. Subnets are /24 slices: public 0-9, private 10-19, data 20-29."
  type        = string
  default     = "10.60.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (one subnet per tier per AZ)."
  type        = number
  default     = 2
}

variable "enable_vpc_endpoints" {
  description = "Create interface endpoints so private workloads reach AWS APIs without internet (SC-7)."
  type        = bool
  default     = true
}

variable "vpc_endpoint_services" {
  description = "Interface endpoint services. FIPS variants resolve the *-fips hostnames privately (SC-13)."
  type        = list(string)
  default     = ["kms-fips", "secretsmanager-fips", "sts-fips", "logs-fips"]
}

variable "vpc_endpoint_subnet_count" {
  description = "How many private subnets (AZs) host each interface endpoint. 1 keeps lab cost down; production uses all."
  type        = number
  default     = 1
}

variable "flow_logs_kms_key_arn" {
  type = string
}

variable "flow_log_retention_days" {
  type    = number
  default = 400
}
