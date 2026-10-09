output "instance_id" {
  value = aws_instance.bastion.id
}

output "role_arn" {
  description = "IAM role of the instance; grant it EKS access with an access entry."
  value       = aws_iam_role.bastion.arn
}

output "security_group_id" {
  value = aws_security_group.bastion.id
}
