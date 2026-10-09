output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — EKS nodes and EFS mount targets go here"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "eks_node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_nodes.id
}

output "efs_security_group_id" {
  description = "Security group ID for EFS mount targets"
  value       = aws_security_group.efs.id
}


output "private_route_table_id" {
  description = "First private route table (kept for backward compatibility)."
  value       = aws_route_table.private[0].id
}

output "private_route_table_ids" {
  description = "All private route tables (one per AZ when nat_gateway_per_az = true)."
  value       = aws_route_table.private[*].id
}
