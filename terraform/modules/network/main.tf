# Network (SC-7, SC-7(5), SC-7(8), SC-7(21), AC-4, CM-7)
# Three tiers across two availability zones: public : internet gateway, only
# for load balancers and NAT if ever needed private : application.

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:The first N names of the sorted list are used; AWS appends new zones, existing ones keep their position
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 10 + i)]
  data_cidrs    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 20 + i)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

# The default security group allows all traffic between its members. Strip it
# so nothing can accidentally rely on it (Security Hub EC2.2).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-default-do-not-use" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-igw" }
}

# Subnets

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${var.name_prefix}-public-${local.azs[count.index]}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.name_prefix}-private-${local.azs[count.index]}", Tier = "private" }
}

resource "aws_subnet" "data" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.data_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.name_prefix}-data-${local.azs[count.index]}", Tier = "data" }
}

# Routing: only the public tier has a route to the internet

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name_prefix}-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-private" }
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-data" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# Network ACLs: stateless deny-by-default per tier (SC-7(5))

resource "aws_network_acl" "public" {
  #checkov:skip=CKV2_AWS_1:Subnets are attached inline through subnet_ids; the check only recognises aws_network_acl_association
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id

  # HTTPS from anywhere (edge / load balancer tier)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Return traffic for connections initiated from this tier. The ephemeral
  # range is split so 3389 (RDP) is never admitted from the internet (CM-7).
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 3388
  }

  ingress {
    rule_no    = 111
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 3390
    to_port    = 65535
  }

  ingress {
    rule_no    = 120
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${var.name_prefix}-public" }
}

resource "aws_network_acl" "private" {
  #checkov:skip=CKV2_AWS_1:Subnets are attached inline through subnet_ids; the check only recognises aws_network_acl_association
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Responses from S3 / DynamoDB gateway endpoints (public address ranges),
  # ephemeral range split around 3389 (CM-7).
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 3388
  }

  ingress {
    rule_no    = 111
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 3390
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = { Name = "${var.name_prefix}-private" }
}

resource "aws_network_acl" "data" {
  #checkov:skip=CKV2_AWS_1:Subnets are attached inline through subnet_ids; the check only recognises aws_network_acl_association
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.data[*].id

  # MySQL only from the private (application) subnets
  dynamic "ingress" {
    for_each = { for i, cidr in local.private_cidrs : i => cidr }
    content {
      rule_no    = 100 + ingress.key
      protocol   = "tcp"
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 3306
      to_port    = 3306
    }
  }

  # Replication and health traffic between data subnets
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 3306
    to_port    = 3306
  }

  tags = { Name = "${var.name_prefix}-data" }
}

# Quarantine security group for incident containment (IR-4(2))
# No rules at all: an instance moved here can neither send nor receive.

resource "aws_security_group" "quarantine" {
  #checkov:skip=CKV2_AWS_5:Intentionally unattached; the containment Lambda attaches it to an instance during an incident
  name        = "${var.name_prefix}-quarantine"
  description = "Incident containment. No ingress, no egress. Applied by the GuardDuty responder."
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-quarantine", Purpose = "quarantine" }
}
