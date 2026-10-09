# AWS EKS — qa
aws_region = "us-east-1"
prefix     = "dragonfly-qa"

tags = {
  Project     = "Dragonfly"
  Platform    = "Unity-Communication"
  Environment = "qa"
  Account     = "rtc-platform-qa"
  Compliance  = "CJIS"
  DataClass   = "Restricted"
  managed_by  = "terraform"
}

vpc_name = "vpc-eks-qa"
# PLACEHOLDER CIDRs: unique per environment AND region so Transit Gateway routing works.
# Replace with the Securus IPAM allocation before any real apply.
vpc_cidr             = "10.20.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
public_subnet_cidrs  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]

kms_deletion_window_days = 30
create_efs               = true
efs_throughput_mode      = "elastic"
k8s_manifest_output_path = "./k8s-manifests"

cluster_name           = "eks-qa-cluster"
kubernetes_version     = "1.36"
endpoint_public_access = false
node_volume_size_gb    = 50

enable_system_node_group   = false
system_node_instance_types = ["t3.medium"]
system_node_desired        = 1
system_node_min            = 1
system_node_max            = 3

user_node_instance_types = ["r5.large"]
user_node_desired        = 1
user_node_min            = 1
user_node_max            = 5

# Add IAM ARNs here to get kubectl/console access to the cluster.
# Find yours with: aws sts get-caller-identity --query Arn --output text
admin_principal_arns = [
  # Client IAM Identity Center / break-glass role ARN(s) go here, e.g.
  # "arn:aws:iam::<account-id>:role/aws-reserved/sso.amazonaws.com/<region>/AWSReservedSSO_<PermissionSet>_<hash>",
]

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
