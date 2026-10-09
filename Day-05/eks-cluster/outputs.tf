output "vpc_id" {
  value = module.vpc.vpc_id
}

output "kms_key_arn" {
  value = module.kms.key_arn
}

output "efs_id" {
  value       = var.create_efs ? module.efs[0].efs_id : null
  description = "null when create_efs = false"
}

output "storageclass_manifest_path" {
  value       = var.create_efs ? module.efs[0].storageclass_manifest_path : null
  description = "null when create_efs = false"
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "cluster_oidc_issuer" {
  value = module.eks.cluster_oidc_issuer
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

# ── AWS Load Balancer Controller outputs ─────────────────────────────────────

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (IRSA)"
  value       = module.eks.alb_controller_role_arn
}

output "alb_controller_policy_arn" {
  description = "IAM policy ARN for the AWS Load Balancer Controller"
  value       = module.eks.alb_controller_policy_arn
}

output "alb_controller_status" {
  description = "Status of the AWS Load Balancer Controller Helm release"
  value       = module.eks.alb_controller_status
}

output "livekit_egress_role_arn" {
  description = "IRSA role ARN to annotate on the LiveKit Egress service account (null if the recording bucket is disabled)"
  value       = try(module.livekit_egress_irsa[0].role_arn, null)
}

output "ebs_csi_role_arn" {
  value = module.eks.ebs_csi_role_arn
}

output "efs_csi_role_arn" {
  value = module.eks.efs_csi_role_arn
}

output "transit_gateway_id" {
  value = try(module.transit_gateway[0].transit_gateway_id, null)
}

output "flow_log_group" {
  value = try(module.vpc_flow_logs[0].log_group_name, null)
}

output "cloudtrail_arn" {
  value = try(module.cloudtrail[0].trail_arn, null)
}

output "secret_arns" {
  value = try(module.secrets[0].secret_arns, {})
}

output "rabbitmq_admin_secret_arn" {
  description = "Secrets Manager secret with the RabbitMQ admin credentials and AMQPS endpoint"
  value       = try(module.rabbitmq[0].admin_secret_arn, null)
}

output "bastion_instance_id" {
  description = "Connect with: aws ssm start-session --target <id>  (or EC2 console > Connect > Session Manager)"
  value       = try(module.bastion[0].instance_id, null)
}

