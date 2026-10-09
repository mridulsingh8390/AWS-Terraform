################################################################################
# Bastion (jump host) for a PRIVATE EKS API endpoint.
#
#   - private subnet, NO public IP, NO inbound rules, NO SSH key
#   - access only through AWS Systems Manager Session Manager (IAM-authenticated,
#     logged), so there is nothing to expose on the internet
#   - encrypted root volume (CMK), IMDSv2 required
#   - kubectl, helm, git, jq pre-installed; kubeconfig is created at first login
#
# The EKS access entry for this instance's role and the "443 from bastion" rule on
# the cluster security group are created in the root module (they need the cluster).
################################################################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── IAM: Session Manager + read-only cluster discovery ───────────────────────

resource "aws_iam_role" "bastion" {
  name = "${var.name}-role"

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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "eks_describe" {
  name = "eks-describe"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-profile"
  role = aws_iam_role.bastion.name
}

# ── Network: no inbound at all ───────────────────────────────────────────────

resource "aws_security_group" "bastion" {
  name        = "${var.name}-sg"
  description = "EKS bastion: no inbound; HTTPS/HTTP out (SSM, EKS API, package downloads)"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS (SSM, EKS API, AWS APIs, downloads)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP (package mirrors)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-sg" })
}

# ── Instance ─────────────────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = false
  monitoring                  = false

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    cluster_name    = var.cluster_name
    region          = var.region
    kubectl_version = var.kubectl_version
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = var.name })

  depends_on = [aws_iam_role_policy_attachment.ssm]
}
