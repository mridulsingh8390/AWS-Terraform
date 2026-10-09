
variable "ami_type" {
  description = "EKS managed node group AMI type. Use BOTTLEROCKET_x86_64_FIPS for Dragonfly FIPS nodes."
  type        = string
  default     = "BOTTLEROCKET_x86_64_FIPS"
}

variable "ami_release_version" {
  description = "Optional pinned EKS managed node group AMI release version. Leave empty to use the EKS recommended version."
  type        = string
  default     = ""
}

variable "node_role_name" {
  description = "Exact IAM role name to create for the node groups. Passed in from root (local.node_role_name) so the kms module's key policy can reference the identical name — do not derive this independently in more than one place."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for etcd envelope encryption and EBS volume encryption"
  type        = string
}

variable "endpoint_public_access" {
  description = "Allow public access to the EKS API endpoint"
  type        = bool
  default     = true
}

variable "bottlerocket_os_volume_size_gb" {
  description = "Size of the Bottlerocket OS volume (/dev/xvda). Only used when ami_type is a BOTTLEROCKET type."
  type        = number
  default     = 4
}

variable "node_volume_size_gb" {
  description = "EBS volume size in GB. On Bottlerocket this is the DATA volume (/dev/xvdb: images, pod storage); on other AMIs it is the root volume."
  type        = number
  default     = 50
}

variable "enable_system_node_group" {
  description = "Create a dedicated system node group with CriticalAddonsOnly taint. Set false for dev/lab to use a single user node pool for all workloads."
  type        = bool
  default     = false
}

# ── System node group ─────────────────────────────────────────────────────────

variable "system_node_instance_types" {
  description = "EC2 instance types for system nodes"
  type        = list(string)
  default     = ["t3.medium"]
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

# ── User node group ───────────────────────────────────────────────────────────

variable "user_node_instance_types" {
  description = "EC2 instance types for user nodes (memory-optimised for PostgreSQL)"
  type        = list(string)
  default     = ["r5.large"]
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
  description = "IAM user/role ARNs to grant cluster-admin Kubernetes access via an EKS access entry (AmazonEKSClusterAdminPolicy, cluster-wide scope). The principal that runs `terraform apply` already gets access automatically (bootstrap_cluster_creator_admin_permissions) and does not need to be listed here."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# ── AWS Load Balancer Controller (ALB Ingress Controller) ────────────────────

variable "enable_alb_ingress_controller" {
  description = "Install AWS Load Balancer Controller (ALB Ingress Controller) via Helm. Requires IRSA (IAM Roles for Service Accounts)."
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

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed. Required for ALB controller to discover subnets."
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB ingress. ALBs will be created in these subnets."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for internal ALB ingress. Internal ALBs will be created in these subnets."
  type        = list(string)
  default     = []
}

# ── Managed add-ons ──────────────────────────────────────────────────────────

variable "enable_managed_addons" {
  description = "Install VPC CNI, CoreDNS, kube-proxy, EBS CSI and (when enable_efs_csi_addon) EFS CSI as EKS managed add-ons."
  type        = bool
  default     = true
}

variable "enable_efs_csi_addon" {
  description = "Install the EFS CSI driver add-on. Set true whenever create_efs = true, otherwise PVCs cannot mount the EFS file system."
  type        = bool
  default     = false
}

variable "addon_versions" {
  description = "Optional pinned add-on versions, keyed by add-on name (vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, aws-efs-csi-driver). Unset = EKS default version for the cluster version. Pin these in prod."
  type        = map(string)
  default     = {}
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the PUBLIC EKS API endpoint. Only used when endpoint_public_access = true. Access is still IAM-authenticated."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

