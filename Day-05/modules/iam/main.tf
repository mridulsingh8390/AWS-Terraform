# =============================================================================
# COMMON MODULE: IAM
# Generic IAM role. Supports two trust modes:
#  1. IRSA mode (set irsa_enabled = true + oidc_provider_arn + oidc_provider_url + namespace +
#     service_account) - builds the OIDC federated trust policy for pods,
#     e.g. the EKS EBS CSI driver's controller service account.
#  2. Custom mode (set assume_role_policy_json) - any other trust policy,
#     e.g. ec2.amazonaws.com for an instance profile.
# =============================================================================

data "aws_iam_policy_document" "irsa_assume_role" {
  count = var.irsa_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name = var.role_name
  assume_role_policy = var.irsa_enabled ? (
    data.aws_iam_policy_document.irsa_assume_role[0].json
  ) : var.assume_role_policy_json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.create_inline_policy ? 1 : 0

  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = "profile-${var.role_name}"
  role = aws_iam_role.this.name

  tags = var.tags
}
