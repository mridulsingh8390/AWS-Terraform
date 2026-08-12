module "vpc" {
  source = "./modules/vpc"

  name                  = var.project_name
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  availability_zones     = var.availability_zones
}

module "security_group" {
  source = "./modules/security-group"

  name     = var.project_name
  vpc_id   = module.vpc.vpc_id
  ssh_cidr = var.ssh_cidr
}

module "key_pair" {
  source = "./modules/key-pair"

  key_name    = "${var.project_name}-key"
  output_path = "${path.module}"
}

module "ec2_instances" {
  source = "./modules/ec2-instance"

  name                = var.project_name
  instance_count      = var.instance_count
  instance_type       = var.instance_type
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.security_group.ec2_security_group_id]
  key_name            = module.key_pair.key_name
}

module "alb" {
  source = "./modules/alb"

  name                  = var.project_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  security_group_ids    = [module.security_group.alb_security_group_id]
  target_instance_ids   = module.ec2_instances.instance_ids
}
