output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "endpoint" {
  description = "Connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname only"
  value       = aws_db_instance.this.address
}

output "arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.this.arn
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the master password, when manage_master_user_password is true"
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}
