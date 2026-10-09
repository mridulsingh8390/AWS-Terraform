output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value     = aws_eks_cluster.eks.endpoint
  sensitive = true
}

output "cluster_ca_data" {
  value     = aws_eks_cluster.eks.certificate_authority[0].data
  sensitive = true
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL — used for IRSA service account federation"
  value       = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// prefix — this is the format IRSA trust policies need, e.g. as consumed by the iam module's oidc_provider_url input"
  value       = replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
}

output "node_role_arn" {
  description = "IAM role ARN for EKS nodes — attach extra policies here"
  value       = aws_iam_role.eks_nodes.arn
}

# ── AWS Load Balancer Controller outputs ─────────────────────────────────────

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (IRSA)"
  value       = var.enable_alb_ingress_controller ? aws_iam_role.alb_controller[0].arn : null
}

output "alb_controller_policy_arn" {
  description = "IAM policy ARN for the AWS Load Balancer Controller"
  value       = var.enable_alb_ingress_controller ? aws_iam_policy.alb_controller[0].arn : null
}

output "alb_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = var.enable_alb_ingress_controller ? helm_release.alb_controller[0].status : null
}

output "ebs_csi_role_arn" {
  value = try(aws_iam_role.ebs_csi[0].arn, null)
}

output "efs_csi_role_arn" {
  value = try(aws_iam_role.efs_csi[0].arn, null)
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group (attached to the control-plane ENIs). Allow 443 from jump hosts here."
  value       = aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id
}

