# VPC endpoints (SC-7, SC-7(8), SC-13)
# Gateway endpoints for S3 and DynamoDB are free and attached to the private
# and data route tables.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.data.id]

  tags = { Name = "${var.name_prefix}-s3" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.data.id]

  tags = { Name = "${var.name_prefix}-dynamodb" }
}

resource "aws_security_group" "endpoints" {
  #checkov:skip=CKV2_AWS_5:Attached to every interface endpoint via security_group_ids on aws_vpc_endpoint
  count = var.enable_vpc_endpoints ? 1 : 0

  name        = "${var.name_prefix}-vpc-endpoints"
  description = "HTTPS from inside the VPC to interface endpoints."
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from the VPC"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.name_prefix}-vpc-endpoints" }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? toset(var.vpc_endpoint_services) : toset([])

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = slice(aws_subnet.private[*].id, 0, var.vpc_endpoint_subnet_count)
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = { Name = "${var.name_prefix}-${each.value}" }
}
