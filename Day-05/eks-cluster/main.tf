################################################################################
# AWS EKS Root Configuration
# Wires: vpc → kms → efs → eks
#
# CMK dependency order:
#   1. KMS key created (with policy granting EKS, EFS, AutoScaling access)
#   2. EFS created (CMK-encrypted via KMS key)
#   3. EKS cluster created (CMK etcd envelope encryption via KMS key)
#   4. EKS nodes created with CMK-encrypted EBS root volumes
################################################################################

# Single source of truth for the node group's IAM role name — fed into both
# the eks module (which creates the role) and the kms module (whose key
# policy needs to reference that exact role). Previously the kms module
# reconstructed this name independently from var.prefix, which only worked
# by naming convention. See modules/kms/main.tf for details.
locals {
  node_role_name = "${var.cluster_name}-nodes-role"
}

module "vpc" {
  source = "../modules/vpc"

  vpc_name                  = var.vpc_name
  prefix                    = var.prefix
  cluster_name              = var.cluster_name
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  private_subnet_cidrs      = var.private_subnet_cidrs
  public_subnet_cidrs       = var.public_subnet_cidrs
  tags                      = var.tags
  enable_nat_gateway        = var.enable_nat_gateway
  facility_cidrs            = var.facility_cidrs
  enable_webrtc_media_rules = var.enable_webrtc_media_rules
  nat_gateway_per_az        = var.nat_gateway_per_az
}

module "kms" {
  source = "../modules/kms"

  prefix                  = var.prefix
  node_role_name          = local.node_role_name
  deletion_window_in_days = var.kms_deletion_window_days
  tags                    = var.tags
}

module "efs" {
  count  = var.create_efs ? 1 : 0
  source = "../modules/efs"

  prefix                   = var.prefix
  kms_key_arn              = module.kms.key_arn
  subnet_ids               = module.vpc.private_subnet_ids
  efs_security_group_id    = module.vpc.efs_security_group_id
  throughput_mode          = var.efs_throughput_mode
  performance_mode         = var.efs_performance_mode
  k8s_manifest_output_path = var.k8s_manifest_output_path
  tags                     = var.tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name                 = var.cluster_name
  node_role_name               = local.node_role_name
  kubernetes_version           = var.kubernetes_version
  ami_type                     = var.ami_type
  ami_release_version          = var.ami_release_version
  subnet_ids                   = module.vpc.private_subnet_ids
  node_security_group_id       = module.vpc.eks_node_security_group_id
  kms_key_arn                  = module.kms.key_arn
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  node_volume_size_gb          = var.node_volume_size_gb

  enable_system_node_group   = var.enable_system_node_group
  system_node_instance_types = var.system_node_instance_types
  system_node_desired        = var.system_node_desired
  system_node_min            = var.system_node_min
  system_node_max            = var.system_node_max

  user_node_instance_types = var.user_node_instance_types
  user_node_desired        = var.user_node_desired
  user_node_min            = var.user_node_min
  user_node_max            = var.user_node_max

  admin_principal_arns = var.admin_principal_arns

  # Managed add-ons (CNI, CoreDNS, kube-proxy, EBS CSI; EFS CSI only if EFS exists)
  enable_managed_addons = var.enable_managed_addons
  enable_efs_csi_addon  = var.create_efs
  addon_versions        = var.addon_versions

  # ALB Ingress Controller
  enable_alb_ingress_controller = var.enable_alb_ingress_controller
  alb_controller_chart_version  = var.alb_controller_chart_version
  alb_controller_namespace      = var.alb_controller_namespace
  alb_controller_replica_count  = var.alb_controller_replica_count
  vpc_id                        = module.vpc.vpc_id
  public_subnet_ids             = module.vpc.public_subnet_ids
  private_subnet_ids            = module.vpc.private_subnet_ids

  tags = var.tags
}


module "vpc_endpoints" {
  count  = var.enable_vpc_endpoints ? 1 : 0
  source = "../modules/vpc-endpoints"

  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = var.vpc_cidr
  region                  = var.aws_region
  private_subnet_ids      = module.vpc.private_subnet_ids
  private_route_table_ids = module.vpc.private_route_table_ids
  name_prefix             = var.prefix
  enable_ssm_endpoints    = var.enable_bastion && !var.enable_nat_gateway
  tags                    = var.tags
}

module "recording_bucket" {
  count  = var.enable_recording_bucket ? 1 : 0
  source = "../modules/s3-recording"

  bucket_name               = "${var.prefix}-livekit-recordings"
  kms_key_arn               = module.kms.key_arn
  retention_days            = var.recording_retention_days
  object_lock_mode          = var.recording_object_lock_mode
  lifecycle_transition_days = var.recording_lifecycle_transition_days
  lifecycle_expiration_days = var.recording_expiration_days
  tags                      = var.tags
}

# ── LiveKit Egress IRSA role ─────────────────────────────────────────────────
# Lets the Egress pods write HLS recordings to the recording bucket and use the
# CMK, without putting S3/KMS rights on the shared node role.

module "livekit_egress_irsa" {
  count  = var.enable_recording_bucket ? 1 : 0
  source = "../modules/iam"

  role_name = "${var.cluster_name}-livekit-egress"

  irsa_enabled         = true
  create_inline_policy = true

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace         = var.livekit_namespace
  service_account   = var.livekit_egress_service_account

  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RecordingBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = module.recording_bucket[0].bucket_arn
      },
      {
        Sid      = "RecordingObjectWrite"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectRetention", "s3:GetObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = "${module.recording_bucket[0].bucket_arn}/*"
      },
      {
        Sid      = "RecordingCmk"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
        Resource = module.kms.key_arn
      },
    ]
  })

  tags = var.tags
}

# ── Inter-region Transit Gateway ─────────────────────────────────────────────
# Optional. The peering ACCEPTER and the TGW static route for the peer CIDR live
# in the other region's stack (different provider region), so they are not here.

module "transit_gateway" {
  count  = var.enable_transit_gateway ? 1 : 0
  source = "../modules/transit-gateway"

  name           = "${var.prefix}-tgw"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  enable_peering = var.tgw_enable_peering
  peer_tgw_id    = var.tgw_peer_tgw_id
  peer_region    = var.tgw_peer_region
  tags           = var.tags
}

# Private route-table routes towards the other VPCs/regions through the TGW.
# Kept in the root (not in module.vpc) because module.transit_gateway consumes
# module.vpc outputs; passing the TGW id back into module.vpc would be circular.
resource "aws_route" "private_tgw" {
  for_each = var.enable_transit_gateway ? {
    for pair in setproduct(range(length(module.vpc.private_route_table_ids)), var.tgw_destination_cidrs) :
    "${pair[0]}|${pair[1]}" => { rt = pair[0], cidr = pair[1] }
  } : {}

  route_table_id         = module.vpc.private_route_table_ids[each.value.rt]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.transit_gateway[0].transit_gateway_id

  # The route is only valid once the VPC attachment is available.
  depends_on = [module.transit_gateway]
}

# ── Observability: VPC flow logs ─────────────────────────────────────────────

module "vpc_flow_logs" {
  count  = var.enable_flow_logs ? 1 : 0
  source = "../modules/vpc-flow-logs"

  name_prefix    = var.prefix
  vpc_id         = module.vpc.vpc_id
  kms_key_arn    = module.kms.key_arn
  retention_days = var.flow_log_retention_days
  tags           = var.tags
}

# ── Audit: CloudTrail (optional) ─────────────────────────────────────────────

module "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  source = "../modules/cloudtrail"

  name            = "${var.prefix}-trail"
  kms_key_arn     = module.kms.key_arn
  expiration_days = var.cloudtrail_expiration_days
  force_destroy   = var.cloudtrail_force_destroy
  tags            = var.tags
}

# ── Secrets Manager baseline ─────────────────────────────────────────────────

module "secrets" {
  count  = length(var.secret_names) > 0 ? 1 : 0
  source = "../modules/secrets"

  name_prefix             = var.prefix
  secret_names            = var.secret_names
  kms_key_arn             = module.kms.key_arn
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

# ── Event backbone: Amazon MQ for RabbitMQ (optional) ────────────────────────

module "rabbitmq" {
  count  = var.enable_rabbitmq ? 1 : 0
  source = "../modules/amazon-mq-rabbitmq"

  name                    = "${var.prefix}-rabbitmq"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_cidrs           = [var.vpc_cidr]
  kms_key_arn             = module.kms.key_arn
  instance_type           = var.rabbitmq_instance_type
  deployment_mode         = var.rabbitmq_deployment_mode
  engine_version          = var.rabbitmq_engine_version
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

# ── Bastion: the only way into a private EKS API ─────────────────────────────

module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "../modules/bastion"

  name            = "${var.prefix}-eks-bastion"
  vpc_id          = module.vpc.vpc_id
  subnet_id       = module.vpc.private_subnet_ids[0]
  kms_key_arn     = module.kms.key_arn
  cluster_name    = module.eks.cluster_name
  region          = var.aws_region
  instance_type   = var.bastion_instance_type
  kubectl_version = var.bastion_kubectl_version
  tags            = var.tags
}

# Created here (not through admin_principal_arns) because the role ARN is only known
# after apply and for_each keys must be known at plan time.
resource "aws_eks_access_entry" "bastion" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion" {
  count = var.enable_bastion ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.bastion[0].role_arn
  policy_arn    = var.bastion_access_policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# Private endpoint: the control-plane ENIs only accept 443 from sources the cluster
# security group allows. Allow the bastion's security group, nothing else.
resource "aws_vpc_security_group_ingress_rule" "bastion_to_cluster" {
  count = var.enable_bastion ? 1 : 0

  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.bastion[0].security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "kubectl/helm from the EKS bastion"
}

