output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "alb_security_group_id" {
  value = module.security_group.alb_security_group_id
}

output "ec2_security_group_id" {
  value = module.security_group.ec2_security_group_id
}

output "key_name" {
  value = module.key_pair.key_name
}

output "pem_file_path" {
  value = module.key_pair.private_key_pem_path
}

output "instance_ids" {
  value = module.ec2_instances.instance_ids
}

output "instance_public_ips" {
  value = module.ec2_instances.public_ips
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "target_group_arn" {
  value = module.alb.target_group_arn
}
