variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "engine" {
  description = "Database engine, e.g. postgres, mysql"
  type        = string
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class, e.g. db.t3.medium"
  type        = string
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max storage for autoscaling, in GB (0 disables)"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type: gp3, gp2, io1, io2"
  type        = string
  default     = "gp3"
}

variable "kms_key_id" {
  description = "KMS key ARN for storage encryption. Leave empty to use the AWS-managed default RDS key"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Initial database name to create"
  type        = string
  default     = ""
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "manage_master_user_password" {
  description = "Let AWS manage the master password in Secrets Manager (recommended). If false, supply var.password"
  type        = bool
  default     = true
}

variable "password" {
  description = "Master password - only used when manage_master_user_password is false"
  type        = string
  default     = null
  sensitive   = true
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "mon:04:30-mon:05:30"
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip taking a final snapshot on destroy"
  type        = bool
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
