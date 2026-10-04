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

variable "logging_kms_key_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 400
}

variable "waf_rate_limit" {
  description = "Requests per 5 minutes from one IP before WAF blocks it (SC-5)."
  type        = number
  default     = 2000
}

variable "acm_certificate_arn" {
  description = "ACM certificate in us-east-1 for a custom domain. Null uses the default CloudFront certificate, which cannot enforce TLS 1.2 (see README)."
  type        = string
  default     = null
}

variable "aliases" {
  description = "Custom domain names for the distribution. Requires acm_certificate_arn."
  type        = list(string)
  default     = []
}
