output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address (EIP if allocated, otherwise the instance's own public IP if any)"
  value       = var.allocate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}
