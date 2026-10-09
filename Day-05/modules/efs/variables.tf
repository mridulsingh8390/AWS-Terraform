variable "prefix" {
  description = "Short prefix for naming resources"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the EFS file system"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for EFS mount targets (one per AZ)"
  type        = list(string)
}

variable "efs_security_group_id" {
  description = "Security group ID for EFS mount targets"
  type        = string
}

variable "throughput_mode" {
  description = "EFS throughput mode: bursting or provisioned"
  type        = string
  default     = "elastic"
}

variable "performance_mode" {
  description = "EFS performance mode: generalPurpose or maxIO"
  type        = string
  default     = "generalPurpose"
}

variable "k8s_manifest_output_path" {
  description = "Directory to write the Kubernetes StorageClass YAML into"
  type        = string
  default     = "./k8s-manifests"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
