output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.cmk.key_id
}

output "key_arn" {
  description = "KMS key ARN — used by EKS cluster secrets encryption and EFS"
  value       = aws_kms_key.cmk.arn
}

output "alias_arn" {
  description = "KMS alias ARN"
  value       = aws_kms_alias.cmk.arn
}
