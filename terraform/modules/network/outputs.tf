output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "availability_zones" {
  value = local.azs
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  value = local.private_cidrs
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "quarantine_security_group_id" {
  value = aws_security_group.quarantine.id
}

output "interface_endpoint_ids" {
  value = { for k, e in aws_vpc_endpoint.interface : k => e.id }
}

output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow_logs.name
}
