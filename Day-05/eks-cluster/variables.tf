variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "create_efs" {
  description = "Whether to create the EFS file system (module.efs). Defaults to false — you must explicitly set create_efs = true in an environment's tfvars for EFS to be created there. Omitting the line entirely means EFS is NOT created."
  type        = bool
  default     = false
}

variable "prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "kms_deletion_window_days" {
  type    = number
  default = 30
}

variable "efs_throughput_mode" {
  type    = string
  default = "elastic"
}

variable "efs_performance_mode" {
  type    = string
  default = "generalPurpose"
}

variable "k8s_manifest_output_path" {
  type    = string
  default = "./k8s-manifests"
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "node_volume_size_gb" {
  type    = number
  default = 50
}

variable "enable_system_node_group" {
  description = "Create a dedicated system node group. Set false for dev to use single user pool."
  type        = bool
  default     = false
}

variable "system_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "system_node_desired" {
  type    = number
  default = 2
}

variable "system_node_min" {
  type    = number
  default = 1
}

variable "system_node_max" {
  type    = number
  default = 3
}

variable "user_node_instance_types" {
  type    = list(string)
  default = ["r5.large"]
}

variable "user_node_desired" {
  type    = number
  default = 2
}

variable "user_node_min" {
  type    = number
  default = 1
}

variable "user_node_max" {
  type    = number
  default = 5
}

variable "admin_principal_arns" {
  description = "IAM user/role ARNs to grant kubectl/cluster-admin access to, via an EKS access entry. Find your own ARN with: aws sts get-caller-identity --query Arn --output text"
  type        = list(string)
  default     = []
}

# ── AWS Load Balancer Controller (ALB Ingress Controller) ────────────────────

variable "enable_alb_ingress_controller" {
  description = "Install AWS Load Balancer Controller (ALB Ingress Controller) via Helm. When true, creates IAM policy, IRSA role, and deploys the controller."
  type        = bool
  default     = false
}

variable "alb_controller_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "1.14.0"
}

variable "alb_controller_namespace" {
  description = "Kubernetes namespace to install the AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "alb_controller_replica_count" {
  description = "Number of replicas for the AWS Load Balancer Controller"
  type        = number
  default     = 1
}


variable "ami_type" {
  description = "EKS managed node group AMI type. Dragonfly production defaults to Bottlerocket FIPS."
  type        = string
  default     = "BOTTLEROCKET_x86_64_FIPS"
}

variable "ami_release_version" {
  description = "Optional pinned Bottlerocket FIPS release version. Leave empty for the EKS recommended version."
  type        = string
  default     = ""
}

variable "enable_vpc_endpoints" {
  description = "Create private AWS service endpoints for ECR, KMS FIPS, STS, Logs, Secrets Manager, CloudWatch Monitoring and ELB."
  type        = bool
  default     = true
}

variable "enable_recording_bucket" {
  description = "Create the Dragonfly LiveKit HLS recording S3 bucket with Object Lock and KMS encryption."
  type        = bool
  default     = true
}

variable "recording_retention_days" {
  description = "Default compliance retention for recording objects. Confirm with Securus before production use."
  type        = number
  default     = 2555
}

variable "recording_object_lock_mode" {
  description = "Object Lock mode for the recording bucket. GOVERNANCE for dev/qa/staging; set COMPLIANCE in prod only after Securus confirms retention (it is immutable, even for root)."
  type        = string
  default     = "GOVERNANCE"
}

variable "recording_lifecycle_transition_days" {
  description = "Days before recording objects transition to Glacier."
  type        = number
  default     = 90
}

variable "recording_expiration_days" {
  description = "Optional recording expiration. Set to 0 to disable expiration."
  type        = number
  default     = 0
}

variable "enable_nat_gateway" {
  description = "Keep NAT egress for lab/external registry access. Production no-internet-egress design should use approved private/mirrored registries and endpoints."
  type        = bool
  default     = true
}


variable "facility_cidrs" {
  description = "Approved Securus facility/SBC CIDRs for SIP."
  type        = list(string)
  default     = []
}

variable "enable_webrtc_media_rules" {
  type    = bool
  default = true
}

# ── Managed add-ons ──────────────────────────────────────────────────────────

variable "enable_managed_addons" {
  description = "Install VPC CNI, CoreDNS, kube-proxy and EBS CSI as EKS managed add-ons (EFS CSI is added automatically when create_efs = true)."
  type        = bool
  default     = true
}

variable "addon_versions" {
  description = "Optional pinned add-on versions (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, aws-efs-csi-driver). Pin in prod."
  type        = map(string)
  default     = {}
}

# ── LiveKit Egress (recording) IRSA ──────────────────────────────────────────

variable "livekit_namespace" {
  description = "Namespace the LiveKit Egress service account lives in. Confirm with the LiveKit deployment."
  type        = string
  default     = "livekit"
}

variable "livekit_egress_service_account" {
  description = "Service account name used by LiveKit Egress pods. Confirm with the LiveKit deployment."
  type        = string
  default     = "livekit-egress"
}

variable "nat_gateway_per_az" {
  description = "One NAT gateway per AZ (HA). Recommended true for prod unless the private-endpoint / no-NAT design is approved."
  type        = bool
  default     = false
}

# ── Inter-region connectivity (Transit Gateway) ──────────────────────────────

variable "enable_transit_gateway" {
  description = "Create a Transit Gateway in this region, attach this VPC, and route tgw_destination_cidrs through it. Off until Securus confirms who owns the TGWs."
  type        = bool
  default     = false
}

variable "tgw_destination_cidrs" {
  description = "CIDRs reachable through the Transit Gateway (e.g. the other region's VPC CIDR). Must not overlap this VPC's CIDR."
  type        = list(string)
  default     = []
}

variable "tgw_enable_peering" {
  description = "Request a TGW peering attachment to peer_tgw_id in tgw_peer_region (the other region's stack must accept it and add a TGW route; see README)."
  type        = bool
  default     = false
}

variable "tgw_peer_tgw_id" {
  type    = string
  default = ""
}

variable "tgw_peer_region" {
  type    = string
  default = ""
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint (only used when endpoint_public_access = true). LAB ONLY: GitLab.com shared runners have no fixed IPs, so dev uses 0.0.0.0/0 (still IAM-authenticated). Keep the endpoint private for qa/staging/prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Observability / audit (SOW Stage 2) ──────────────────────────────────────

variable "enable_flow_logs" {
  description = "VPC flow logs to a CMK-encrypted CloudWatch log group."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for flow logs (valid CloudWatch values only, e.g. 30, 90, 365, 731). Set from the client's audit-retention policy."
  type        = number
  default     = 365
}

variable "enable_cloudtrail" {
  description = "Account-level multi-region CloudTrail. Leave false if an organization trail (Control Tower) already covers this account."
  type        = bool
  default     = false
}

variable "cloudtrail_expiration_days" {
  description = "Delete CloudTrail logs after N days; 0 = keep forever."
  type        = number
  default     = 0
}

variable "cloudtrail_force_destroy" {
  description = "Allow destroy to delete a non-empty CloudTrail bucket (lab only)."
  type        = bool
  default     = false
}

# ── Secrets Manager baseline ─────────────────────────────────────────────────

variable "secret_names" {
  description = "Empty, CMK-encrypted Secrets Manager containers to create (names without the prefix). Values are set outside Terraform."
  type        = list(string)
  default     = []
}

variable "secret_recovery_window_days" {
  description = "Recovery window for deleted secrets (0 = immediate, lab only)."
  type        = number
  default     = 7
}

# ── RabbitMQ event backbone ──────────────────────────────────────────────────

variable "enable_rabbitmq" {
  description = "Create the Amazon MQ for RabbitMQ broker (event backbone). Decision pending with Securus: Amazon MQ vs self-managed RabbitMQ on EKS."
  type        = bool
  default     = false
}

variable "rabbitmq_instance_type" {
  type    = string
  default = "mq.t3.micro"
}

variable "rabbitmq_deployment_mode" {
  type    = string
  default = "SINGLE_INSTANCE"
}

variable "rabbitmq_engine_version" {
  description = "Amazon MQ RabbitMQ engine version available in the region; pin it."
  type        = string
  default     = "3.13"
}

# ── Bastion (jump host) for a private EKS API ────────────────────────────────

variable "enable_bastion" {
  description = "Create an SSM-only jump host in a private subnet with cluster-admin access, for use when the EKS API endpoint is private."
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  type    = string
  default = "t2.small"
}

variable "bastion_kubectl_version" {
  description = "kubectl version installed on the bastion (within one minor version of kubernetes_version)."
  type        = string
  default     = "v1.36.2"
}

variable "bastion_access_policy_arn" {
  description = "EKS access policy for the bastion role. Cluster admin lets it run kubectl/helm; use AmazonEKSViewPolicy for read-only."
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

