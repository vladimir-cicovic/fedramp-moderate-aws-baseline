output "data_kms_key_arn" {
  value = aws_kms_key.data.arn
}

output "data_kms_key_id" {
  value = aws_kms_key.data.key_id
}

output "data_kms_key_alias" {
  value = aws_kms_alias.data.name
}
