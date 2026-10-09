variable "prefix" {
  description = "Short prefix used to name the KMS key and alias"
  type        = string
}

variable "node_role_name" {
  description = "Exact IAM role name of the EKS node group role (passed in from root, sourced from the same local as the eks module's node_role_name input, so this can never drift out of sync with the role the eks module actually creates)"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Waiting period (7-30 days) before KMS key is deleted after scheduled deletion"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}
