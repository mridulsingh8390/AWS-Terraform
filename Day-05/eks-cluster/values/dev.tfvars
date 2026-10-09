# AWS EKS — dev
aws_region = "us-east-1"
prefix     = "dragonfly-dev"

tags = {
  Project     = "Dragonfly"
  Platform    = "Unity-Communication"
  Environment = "dev"
  Account     = "rtc-platform-dev"
  Compliance  = "CJIS"
  DataClass   = "Restricted"
  managed_by  = "terraform"
}

vpc_name = "vpc-eks-dev"
# PLACEHOLDER CIDRs: unique per environment AND region so Transit Gateway routing works.
# Replace with the Securus IPAM allocation before any real apply.
vpc_cidr             = "10.10.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
public_subnet_cidrs  = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]

kms_deletion_window_days = 30
create_efs               = true
efs_throughput_mode      = "elastic"
k8s_manifest_output_path = "./k8s-manifests"

cluster_name       = "eks-dev-cluster"
kubernetes_version = "1.36"
# LAB ONLY: the GitLab.com shared runner cannot reach a private-only EKS API, and
# Terraform installs the ALB controller (Helm) through that API. Access is still
# IAM-authenticated. Switch back to false when a self-hosted runner inside/peered to
# the VPC is available. qa / staging / prod stay private.
endpoint_public_access = true
node_volume_size_gb    = 50

enable_system_node_group   = false
system_node_instance_types = ["t3.medium"]
system_node_desired        = 1
system_node_min            = 1
system_node_max            = 3

user_node_instance_types = ["t3.large"]
user_node_desired        = 1
user_node_min            = 1
user_node_max            = 5

# No personal/admin IAM users get cluster access through Terraform.
#   - Terraform's CI role is cluster-admin (it created the cluster).
#   - The bastion's role is cluster-admin (see enable_bastion below); people reach the
#     cluster by starting a Session Manager session on the bastion.
# Add an IAM Identity Center role ARN here (role ARN WITHOUT the
# aws-reserved/sso.amazonaws.com/<region>/ path) only if someone needs the EKS console
# "Resources" tab or CloudShell kubectl, which also requires a public endpoint.
admin_principal_arns = []

# ── AWS Load Balancer Controller (ALB Ingress Controller) ────────────────────
enable_alb_ingress_controller = true
alb_controller_chart_version  = "1.14.0"
alb_controller_namespace      = "kube-system"
alb_controller_replica_count  = 1

# Dragonfly FIPS node baseline
ami_type                            = "BOTTLEROCKET_x86_64_FIPS"
ami_release_version                 = ""
enable_vpc_endpoints                = true
enable_recording_bucket             = true
recording_retention_days            = 7 # lab/non-prod placeholder; real value comes from Securus retention policy
recording_object_lock_mode          = "GOVERNANCE"
recording_lifecycle_transition_days = 90
recording_expiration_days           = 0
enable_nat_gateway                  = true

facility_cidrs = [] # Populate only with Securus-approved SBC/facility CIDRs

# ── Observability / audit / secrets / event backbone (SOW Stage 2) ───────────
enable_flow_logs        = true
flow_log_retention_days = 30 # lab; real value from the Securus audit-retention policy

# Lab account: no Control Tower org trail is assumed. Set false if one already covers it.
enable_cloudtrail        = true
cloudtrail_force_destroy = true # lab only, lets destroy remove a non-empty bucket

# Empty, CMK-encrypted containers; values are set outside Terraform.
secret_names                = ["livekit/api-keys", "postgres/credentials"]
secret_recovery_window_days = 0 # lab only: immediate delete so destroy/re-create works

# Amazon MQ for RabbitMQ (decision pending with Securus: Amazon MQ vs RabbitMQ on EKS)
enable_rabbitmq          = true
rabbitmq_instance_type   = "mq.t3.micro"
rabbitmq_deployment_mode = "SINGLE_INSTANCE"
rabbitmq_engine_version  = "3.13"

# ── Bastion (SSM-only jump host for the private-API model) ───────────────────
# Dev keeps the public endpoint for now (the GitLab.com runner needs it). Inside the VPC
# the cluster name resolves to PRIVATE addresses, so the bastion already uses the private
# path and proves it works before the endpoint is switched to private.
enable_bastion        = true
bastion_instance_type = "t2.small"

