################################################################################
# AWS KMS Module
# Creates: KMS Customer Managed Key + alias used to encrypt
#   - EKS cluster secrets (envelope encryption of etcd)
#   - EBS volumes attached to EKS nodes
#   - EFS file system (NFS for PostgreSQL PVC)
#
# FIX: Key policy now includes node role ARN and AutoScaling service-linked
# role directly — this prevents Client.InternalError on node launch caused
# by nodes being unable to decrypt their CMK-encrypted EBS root volumes.
#
# NOTE: var.node_role_name is passed in from root (see local.node_role_name
# in aws/eks-cluster/main.tf) and fed into BOTH this module and the eks
# module. Previously this was independently reconstructed here as
# "${var.prefix}-cluster-nodes-role", which only matched the eks module's
# real role name by convention — a silent, undetectable mismatch if that
# convention ever drifted. Single source of truth now removes that risk.
################################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# The caller ARN of a CI job is an assumed-role SESSION ARN
# (arn:aws:sts::<acct>:assumed-role/<role>/<session>) whose session name changes
# on every run, which would rewrite the key policy on every apply. Resolve the
# underlying role/user ARN instead.
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_kms_key" "cmk" {
  description             = "${var.prefix} CMK - encrypts EKS, EBS, EFS"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Root account — full control, prevents accidental lockout
      {
        Sid    = "AllowRootAccountFullControl"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Calling IAM user/role (Terraform deployer) — full control
      {
        Sid    = "AllowCallerFullControl"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_session_context.current.issuer_arn
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # EKS service — for etcd secrets envelope encryption
      {
        Sid    = "AllowEKSSecretsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
      # EFS service — for NFS file system encryption
      {
        Sid    = "AllowEFSEncryption"
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      # AutoScaling service-linked role — for EBS encryption on node launch
      # Must use the IAM role ARN, not the service principal, for EBS grants
      {
        Sid    = "AllowAutoScalingEBSEncryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      # EC2 service — for EBS volume operations during instance launch
      {
        Sid    = "AllowEC2EBSEncryption"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
      # CloudWatch Logs — encrypted log groups (VPC flow logs, etc.)
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      },
      # CloudTrail — encrypt trail log files
      {
        Sid    = "AllowCloudTrailEncrypt"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "kms:GenerateDataKey*"
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
          }
        }
      },
      {
        Sid    = "AllowCloudTrailDescribeKey"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "kms:DescribeKey"
        Resource = "*"
      },
      # EKS node IAM role — decrypt EBS volumes on node boot
      # This is the critical fix: nodes must be able to use the key
      # before they can mount their root volume and start up.
      {
        Sid    = "AllowEKSNodeRoleEBSAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.node_role_name}"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, { Name = "${var.prefix}-cmk" })
}

resource "aws_kms_alias" "cmk" {
  name          = "alias/${var.prefix}-cmk"
  target_key_id = aws_kms_key.cmk.key_id
}
