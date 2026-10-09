################################################################################
# AWS EFS Module
# Creates: EFS file system (CMK-encrypted) + mount targets in each subnet
# Writes the EFS CSI StorageClass YAML to disk for kubectl apply
################################################################################

resource "aws_efs_file_system" "postgres" {
  creation_token  = "${var.prefix}-postgres-efs"
  encrypted       = true
  kms_key_id      = var.kms_key_arn
  throughput_mode = var.throughput_mode

  performance_mode = var.performance_mode

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(var.tags, { Name = "${var.prefix}-postgres-efs" })
}

# ── Mount targets — one per subnet (AZ) so pods on any node can mount ─────────

resource "aws_efs_mount_target" "postgres" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.postgres.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.efs_security_group_id]
}

# ── EFS Access Point — gives PostgreSQL pods an isolated directory ─────────────
# Access point enforces UID/GID 999 (standard PostgreSQL container user)

resource "aws_efs_access_point" "postgres" {
  file_system_id = aws_efs_file_system.postgres.id

  posix_user {
    uid = 999
    gid = 999
  }

  root_directory {
    path = "/postgres"
    creation_info {
      owner_uid   = 999
      owner_gid   = 999
      permissions = "0750"
    }
  }

  tags = merge(var.tags, { Name = "${var.prefix}-efs-ap-postgres" })
}

# ── Kubernetes StorageClass manifest ─────────────────────────────────────────

resource "local_file" "storageclass" {
  filename = "${var.k8s_manifest_output_path}/efs-postgres-storageclass.yaml"
  content  = <<-YAML
    # EFS CSI StorageClass for PostgreSQL PVC
    # CMK encryption is enforced at the EFS file system level.
    # Prerequisite: the EFS CSI driver is installed by Terraform as the EKS managed
    # add-on aws-efs-csi-driver (enable_managed_addons = true, create_efs = true).
    # Apply: kubectl apply -f efs-postgres-storageclass.yaml
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: efs-postgres-cmk
    provisioner: efs.csi.aws.com
    reclaimPolicy: Retain
    volumeBindingMode: Immediate
    parameters:
      provisioningMode: efs-ap
      fileSystemId:     ${aws_efs_file_system.postgres.id}
      directoryPerms:   "0750"
      basePath:         /postgres
      uid:              "999"
      gid:              "999"
    # "iam" is intentionally NOT set: it makes the node plugin sign mount requests with
    # the node role, which no longer has EFS permissions. Access is controlled by the
    # EFS security group, the access point and TLS. If the client requires IAM
    # authorization (EFS file system policy), add "iam" back AND grant the node
    # plugin credentials (node role policy or Pod Identity on efs-csi-node-sa).
    mountOptions:
      - tls
  YAML
}
