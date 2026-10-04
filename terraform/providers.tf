# Primary region. FedRAMP Moderate Equivalency on commercial AWS: use a US
# region
# where FIPS 140-validated endpoints are available (us-east-1 / us-west-2).
provider "aws" {
  region            = var.region
  profile           = var.aws_profile
  use_fips_endpoint = var.use_fips_endpoints

  default_tags {
    tags = local.common_tags
  }
}

# IAM Identity Center is a regional service pinned to the region where it was
# enabled.
provider "aws" {
  alias             = "sso"
  region            = coalesce(var.identity_center_region, var.region)
  profile           = var.aws_profile
  use_fips_endpoint = var.use_fips_endpoints

  default_tags {
    tags = local.common_tags
  }
}
