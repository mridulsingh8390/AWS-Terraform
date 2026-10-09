variable "name" {
  description = "Broker name, e.g. dragonfly-dev-rabbitmq."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnet IDs. SINGLE_INSTANCE uses the first one."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach AMQPS (5671) and the management UI (443). Normally the VPC CIDR."
  type        = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "engine_version" {
  description = "RabbitMQ engine version supported by Amazon MQ in this region. Check the available versions and pin one."
  type        = string
  default     = "3.13"
}

variable "instance_type" {
  description = "mq.t3.micro for lab; use an mq.m5.* size for real environments."
  type        = string
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  type    = string
  default = "SINGLE_INSTANCE"

  validation {
    condition     = contains(["SINGLE_INSTANCE", "CLUSTER_MULTI_AZ"], var.deployment_mode)
    error_message = "deployment_mode must be SINGLE_INSTANCE or CLUSTER_MULTI_AZ."
  }
}

variable "admin_username" {
  type    = string
  default = "dragonfly_admin"
}

variable "enable_general_logs" {
  description = "Publish RabbitMQ general logs to CloudWatch Logs (check the log-publishing permissions before enabling)."
  type        = bool
  default     = false
}

variable "recovery_window_in_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
