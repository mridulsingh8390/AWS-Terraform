variable "name" {
  description = "Name tag for the instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID to launch"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "Subnet to launch the instance in"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach"
  type        = list(string)
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Leave empty if using SSM/Tailscale only"
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "Assign a public IP on launch"
  type        = bool
  default     = false
}

variable "allocate_eip" {
  description = "Allocate and attach a dedicated Elastic IP"
  type        = bool
  default     = false
}

variable "instance_profile_name" {
  description = "IAM instance profile name to attach (build with the iam module)"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "Cloud-init / user-data script"
  type        = string
  default     = ""
}

variable "user_data_replace_on_change" {
  description = "Replace the instance when user_data changes"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
