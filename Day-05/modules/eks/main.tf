################################################################################
# AWS EKS Module
# Creates: EKS cluster (CMK envelope encryption of etcd secrets),
# system + user managed node groups (EBS volumes CMK-encrypted),
# required IAM roles
################################################################################

data "aws_caller_identity" "current" {}

# ── IAM Role — EKS cluster control plane ──────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── IAM Role — EKS managed node group ────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  name = var.node_role_name != "" ? var.node_role_name : "${var.cluster_name}-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_readonly" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# NOTE: no EFS client policy on the node role on purpose. The EFS CSI controller
# uses its own IRSA role (aws_iam_role.efs_csi). Mounts rely on the EFS mount-target
# security group, the access point and TLS - not on node-role IAM.

# ── Launch template — enforces CMK encryption on ALL node EBS volumes ────────
# Bottlerocket has TWO volumes: /dev/xvda (read-only OS) and /dev/xvdb (data:
# container images, pod ephemeral storage, logs). Only mapping xvda would leave
# the data volume outside the CMK, so both are mapped here. On other AMIs only
# the root volume exists.

locals {
  is_bottlerocket = startswith(var.ami_type, "BOTTLEROCKET")
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.cluster_name}-node-lt-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = local.is_bottlerocket ? var.bottlerocket_os_volume_size_gb : var.node_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  dynamic "block_device_mappings" {
    for_each = local.is_bottlerocket ? [1] : []
    content {
      device_name = "/dev/xvdb"
      ebs {
        volume_size           = var.node_volume_size_gb
        volume_type           = "gp3"
        encrypted             = true
        kms_key_id            = var.kms_key_arn
        delete_on_termination = true
      }
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required — security best practice
    http_put_response_hop_limit = 1
  }

  tags = var.tags
}

# ── EKS Cluster ────────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [var.node_security_group_id]
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
    endpoint_private_access = true
  }

  # API_AND_CONFIG_MAP (rather than the CONFIG_MAP default) enables EKS
  # Access Entries below — without this block, ONLY the IAM principal that
  # ran `terraform apply` (in our case, the GitLab OIDC role) gets
  # Kubernetes access, and there is no supported way to add anyone else
  # short of assuming that exact role. bootstrap_cluster_creator_admin_permissions
  # keeps that original behavior (the applying principal still gets admin)
  # so CI can keep managing the cluster after this change.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # CMK envelope encryption of Kubernetes secrets in etcd
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = var.kms_key_arn
    }
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# ── System node group (optional) — runs kube-system pods only ────────────────
# Disabled by default for dev — set enable_system_node_group = true for prod

resource "aws_eks_node_group" "system" {
  count           = var.enable_system_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  ami_type        = var.ami_type
  release_version = var.ami_release_version != "" ? var.ami_release_version : null
  instance_types  = var.system_node_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.system_node_desired
    min_size     = var.system_node_min
    max_size     = var.system_node_max
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "nodepool-type" = "system"
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-system-node" })

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_readonly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ── User node group — runs app + PostgreSQL pods ──────────────────────────────

resource "aws_eks_node_group" "user" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "${var.cluster_name}-user"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids

  ami_type        = var.ami_type
  release_version = var.ami_release_version != "" ? var.ami_release_version : null
  instance_types  = var.user_node_instance_types

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.user_node_desired
    min_size     = var.user_node_min
    max_size     = var.user_node_max
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    "nodepool-type" = "user"
    "workload"      = "application"
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-user-node" })

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_readonly,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ── OIDC Provider — enables IRSA (IAM Roles for Service Accounts) ─────────────

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  tags = var.tags
}

# ── KMS grants — allows node role and AutoScaling to use CMK for EBS ─────────
# Belt-and-suspenders: key policy (in kms module) + grants here both grant
# access so nodes can decrypt EBS volumes on launch regardless of policy
# propagation timing.

resource "aws_kms_grant" "nodes_ebs" {
  name              = "${var.cluster_name}-nodes-ebs-grant"
  key_id            = var.kms_key_arn
  grantee_principal = aws_iam_role.eks_nodes.arn

  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant",
  ]
}

resource "aws_kms_grant" "autoscaling_ebs" {
  name              = "${var.cluster_name}-autoscaling-ebs-grant"
  key_id            = var.kms_key_arn
  grantee_principal = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"

  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant",
  ]
}

# ── Human/other IAM access to the Kubernetes API ─────────────────────────────
# Only the applying principal (bootstrap_cluster_creator_admin_permissions
# above) gets access by default. Anyone else — your own IAM user for
# `kubectl`/CloudShell access, another team's role, etc. — needs an explicit
# access entry here. Requires access_config.authentication_mode to include
# API (set above).

resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.admin_principal_arns)

  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}



################################################################################
# AWS Load Balancer Controller (ALB Ingress Controller)
# Creates: IAM policy, IRSA role, and Helm release
################################################################################

# ── IAM Policy — AWS Load Balancer Controller ────────────────────────────────
# Policy derived from AWS official documentation:
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

resource "aws_iam_policy" "alb_controller" {
  count = var.enable_alb_ingress_controller ? 1 : 0

  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"
  path        = "/"

  # Official policy shipped with the controller release that matches
  # alb_controller_chart_version (chart 1.14.0 = controller v2.14.0):
  #   https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/docs/install/iam_policy.json
  # A hand-copied subset was missing 7 actions (ec2:DescribeRouteTables,
  # ec2:GetSecurityGroupsForVpc, elasticloadbalancing:SetRulePriorities, ...), which
  # shows up as AccessDenied in the controller logs. When you bump the chart version,
  # replace this file with the policy from the matching controller tag.
  policy = file("${path.module}/alb-controller-iam-policy.json")

  tags = var.tags
}

# ── IAM Role for Service Account (IRSA) — ALB Controller ─────────────────────

resource "aws_iam_role" "alb_controller" {
  count = var.enable_alb_ingress_controller ? 1 : 0

  name = "${var.cluster_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.alb_controller_namespace}:aws-load-balancer-controller"
          "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  count = var.enable_alb_ingress_controller ? 1 : 0

  role       = aws_iam_role.alb_controller[0].name
  policy_arn = aws_iam_policy.alb_controller[0].arn
}

# ── Helm Release — AWS Load Balancer Controller ──────────────────────────────

resource "helm_release" "alb_controller" {
  count = var.enable_alb_ingress_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = var.alb_controller_namespace

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "replicaCount"
    value = var.alb_controller_replica_count
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller[0].arn
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  # The controller registers a webhook, so pod networking (CNI, kube-proxy) and DNS
  # must be up before the chart is installed.
  timeout = 600

  depends_on = [
    aws_eks_node_group.user,
    aws_iam_role_policy_attachment.alb_controller,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
  ]
}

# ── Data source for current region ────────────────────────────────────────────

data "aws_region" "current" {}

################################################################################
# EKS managed add-ons + CSI drivers
#
# Without these, the cluster has no EBS/EFS CSI driver, so a PVC bound to the
# EFS file system (create_efs = true) or to an EBS StorageClass can never mount.
# CSI controllers use IRSA roles scoped to the driver's service account instead
# of widening the node role.
################################################################################

locals {
  oidc_host = replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")
}

# ── EBS CSI controller role (IRSA) ───────────────────────────────────────────

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_managed_addons ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_managed_addons ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Volumes created by the CSI driver are encrypted with the CMK, so the
# controller needs the key (AmazonEBSCSIDriverPolicy only covers AWS-managed keys).
resource "aws_iam_role_policy" "ebs_csi_kms" {
  count = var.enable_managed_addons ? 1 : 0
  name  = "ebs-csi-cmk"
  role  = aws_iam_role.ebs_csi[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect    = "Allow"
        Action    = "kms:CreateGrant"
        Resource  = var.kms_key_arn
        Condition = { Bool = { "kms:GrantIsForAWSResource" = "true" } }
      },
    ]
  })
}

# ── EFS CSI controller role (IRSA) ───────────────────────────────────────────

resource "aws_iam_role" "efs_csi" {
  count = var.enable_managed_addons && var.enable_efs_csi_addon ? 1 : 0
  name  = "${var.cluster_name}-efs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count      = var.enable_managed_addons && var.enable_efs_csi_addon ? 1 : 0
  role       = aws_iam_role.efs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# ── Add-ons ──────────────────────────────────────────────────────────────────
# Created after the node group so CoreDNS / CSI pods have somewhere to schedule.

resource "aws_eks_addon" "vpc_cni" {
  count        = var.enable_managed_addons ? 1 : 0
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "vpc-cni"

  addon_version               = lookup(var.addon_versions, "vpc-cni", null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  count        = var.enable_managed_addons ? 1 : 0
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"

  addon_version               = lookup(var.addon_versions, "kube-proxy", null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  count        = var.enable_managed_addons ? 1 : 0
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "coredns"

  addon_version               = lookup(var.addon_versions, "coredns", null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.user, aws_eks_node_group.system]
}

resource "aws_eks_addon" "ebs_csi" {
  count        = var.enable_managed_addons ? 1 : 0
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = lookup(var.addon_versions, "aws-ebs-csi-driver", null)
  service_account_role_arn    = aws_iam_role.ebs_csi[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  depends_on = [
    aws_eks_node_group.user,
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_role_policy.ebs_csi_kms,
  ]
}

resource "aws_eks_addon" "efs_csi" {
  count        = var.enable_managed_addons && var.enable_efs_csi_addon ? 1 : 0
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "aws-efs-csi-driver"

  addon_version               = lookup(var.addon_versions, "aws-efs-csi-driver", null)
  service_account_role_arn    = aws_iam_role.efs_csi[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  depends_on = [
    aws_eks_node_group.user,
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.efs_csi,
  ]
}

