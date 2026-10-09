variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "prefix" {
  description = "Short prefix for naming child resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used in subnet tags so EKS can discover them"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to create subnets in"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ, EKS nodes live here)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (NAT GW lives here)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}


variable "enable_nat_gateway" {
  description = "Create NAT gateway for private subnet internet egress."
  type        = bool
  default     = true
}


variable "facility_cidrs" {
  description = "Approved facility/SBC CIDRs for SIP traffic. Leave empty until Securus provides approved ranges."
  type        = list(string)
  default     = []
}

variable "enable_webrtc_media_rules" {
  description = "Enable WebRTC/STUN UDP media rules. Confirm approved port ranges with Securus first."
  type        = bool
  default     = true
}

variable "nat_gateway_per_az" {
  description = "One NAT gateway (and private route table) per AZ for HA. false = single shared NAT (lab/cost)."
  type        = bool
  default     = false
}
