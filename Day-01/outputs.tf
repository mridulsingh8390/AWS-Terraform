output "instance_id" {
  value = module.ec2_instance.instance_id
}

output "instance_public_ip" {
  value = module.ec2_instance.public_ip
}

output "instance_public_dns" {
  value = module.ec2_instance.public_dns
}

output "security_group_id" {
  value = module.security_group.security_group_id
}

output "default_vpc_id" {
  value = data.aws_vpc.default.id
}
