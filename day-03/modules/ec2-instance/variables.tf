variable "name" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "instance_type" {
  type = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to spread instances across (round-robin)"
  type        = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}
