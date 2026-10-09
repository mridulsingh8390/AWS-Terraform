variable "name" {
  description = "Name prefix, e.g. dragonfly-dev-eks-bastion."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "PRIVATE subnet to place the instance in."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK for the encrypted root volume."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.small"
}

variable "kubectl_version" {
  description = "kubectl release to install (within one minor version of the cluster)."
  type        = string
  default     = "v1.36.2"
}

variable "root_volume_gb" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
