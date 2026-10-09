variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "region" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "private_route_table_ids" {
  type = list(string)
}

variable "name_prefix" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enable_ssm_endpoints" {
  description = "Add the SSM / SSM-messages / EC2-messages interface endpoints so Session Manager works without a NAT gateway."
  type        = bool
  default     = false
}

