variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "enable_peering" {
  type    = bool
  default = false
}

variable "peer_tgw_id" {
  type    = string
  default = ""
}

variable "peer_region" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
