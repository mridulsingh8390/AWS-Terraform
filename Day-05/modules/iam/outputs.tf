output "role_arn" {
  description = "ARN of the created IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the created IAM role"
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "Name of the created instance profile, if any"
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}
