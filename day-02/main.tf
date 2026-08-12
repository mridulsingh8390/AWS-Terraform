module "vpc" {
  source = "./modules/vpc"

  name                = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  availability_zone    = var.availability_zone
}

module "security_group" {
  source = "./modules/security-group"

  name     = "${var.project_name}-sg"
  vpc_id   = module.vpc.vpc_id
  ssh_cidr = var.ssh_cidr
}

module "key_pair" {
  source = "./modules/key-pair"

  key_name    = "${var.project_name}-key"
  output_path = "${path.module}"
}

module "ec2_instance" {
  source = "./modules/ec2-instance"

  name                = var.project_name
  instance_type       = var.instance_type
  subnet_id           = module.vpc.public_subnet_id
  security_group_ids  = [module.security_group.security_group_id]
  key_name            = module.key_pair.key_name
}
