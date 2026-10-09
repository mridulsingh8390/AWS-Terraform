# =============================================================================
# COMMON MODULE: EC2
# Generic single-instance module - e.g. a jumpbox/bastion into a private EKS
# cluster, mirroring the Azure repo's azure-linux-virtual-machine jumpbox use.
# =============================================================================

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.vpc_security_group_ids
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.instance_profile_name != "" ? var.instance_profile_name : null
  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data_replace_on_change

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type            = var.root_volume_type
    encrypted              = true
    delete_on_termination  = true
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_eip" "this" {
  count    = var.allocate_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = merge(var.tags, {
    Name = "eip-${var.name}"
  })
}
