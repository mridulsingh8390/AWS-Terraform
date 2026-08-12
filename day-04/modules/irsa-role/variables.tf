variable "role_name" {
  type = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (from the eks-cluster module)"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL, without the https:// prefix"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name allowed to assume this role"
  type        = string
}

variable "policy_arn" {
  description = "IAM policy ARN to attach to this role"
  type        = string
}
