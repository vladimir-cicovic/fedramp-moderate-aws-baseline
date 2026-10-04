terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Local state for the lab. For a real environment move this to an S3 backend
  # with SSE-KMS, versioning, Object Lock and DynamoDB locking (CM-3, AU-9).
}
