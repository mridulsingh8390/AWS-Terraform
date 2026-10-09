output "broker_id" {
  value = aws_mq_broker.this.id
}

output "broker_arn" {
  value = aws_mq_broker.this.arn
}

output "admin_secret_arn" {
  description = "Secrets Manager secret holding the admin credentials and endpoint."
  value       = aws_secretsmanager_secret.admin.arn
}

output "security_group_id" {
  value = aws_security_group.mq.id
}
