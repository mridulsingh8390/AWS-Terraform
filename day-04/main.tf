module "vpc" {
  source = "./modules/vpc"

  name                  = var.project_name
  vpc_cidr               = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  availability_zones     = var.availability_zones
  cluster_name           = var.cluster_name
}

module "eks" {
  source = "./modules/eks-cluster"

  cluster_name          = var.cluster_name
  cluster_version       = var.cluster_version
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnet_ids
  node_instance_type    = var.node_instance_type
  node_desired_size     = var.node_desired_size
  node_min_size         = var.node_min_size
  node_max_size         = var.node_max_size
}

# IRSA role for the AWS Load Balancer Controller — lets the controller
# create/manage ALBs on your behalf using the OIDC provider above,
# instead of a Service of type LoadBalancer creating its own separate ELB.
module "alb_controller_irsa" {
  source = "./modules/irsa-role"

  role_name             = "${var.cluster_name}-alb-controller-role"
  oidc_provider_arn     = module.eks.oidc_provider_arn
  oidc_provider_url     = module.eks.oidc_provider_url
  namespace             = "kube-system"
  service_account_name  = "aws-load-balancer-controller"
  policy_arn            = var.alb_controller_policy_arn
}
