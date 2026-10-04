output "cluster_arn" {
  value = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "master_user_secret_arn" {
  value = try(aws_rds_cluster.this.master_user_secret[0].secret_arn, null)
}

output "security_group_id" {
  value = aws_security_group.db.id
}
