data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "security_group" {
  source = "./modules/security-group"

  name     = "${var.instance_name}-sg"
  vpc_id   = data.aws_vpc.default.id
  ssh_cidr = var.ssh_cidr
}

module "ec2_instance" {
  source = "./modules/ec2-instance"

  name                = var.instance_name
  instance_type       = var.instance_type
  subnet_id           = data.aws_subnets.default.ids[0]
  security_group_ids  = [module.security_group.security_group_id]
  key_pair_name       = var.key_pair_name
}
