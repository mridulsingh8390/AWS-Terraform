variable "name" {
  description = "Security group name"
  type        = string
}

variable "description" {
  description = "Security group description"
  type        = string
  default     = "Managed by Terraform"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rule objects: { description, from_port, to_port, protocol, cidr_blocks, security_groups, self }"
  type        = any
  default     = []
}

variable "egress_rules" {
  description = "List of egress rule objects: { description, from_port, to_port, protocol, cidr_blocks, security_groups, self }"
  type        = any
  default = [
    {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
