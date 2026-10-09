variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of AWS managed or customer managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline policy JSON document"
  type        = string
  default     = ""
}

variable "assume_role_policy_json" {
  description = "Custom assume-role trust policy JSON. Ignored if oidc_provider_arn is set (IRSA mode)"
  type        = string
  default     = ""
}

variable "create_instance_profile" {
  description = "Also create an EC2 instance profile for this role"
  type        = bool
  default     = false
}

# --- IRSA mode ---

variable "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (from the eks module's oidc_provider_arn output). Set this to enable IRSA trust-policy mode"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS cluster OIDC provider URL without the https:// prefix (from the eks module's oidc_provider_url output)"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace of the service account, for IRSA trust conditions"
  type        = string
  default     = "kube-system"
}

variable "service_account" {
  description = "Kubernetes service account name, for IRSA trust conditions"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# These two flags are plain booleans on purpose. Terraform needs `count` to be known
# at plan time, but oidc_provider_arn and inline_policy_json usually contain values
# that only exist after apply (a new cluster's OIDC ARN, a new bucket's ARN), so
# the module cannot decide from them.
variable "irsa_enabled" {
  description = "Build the IRSA (OIDC federated) trust policy from oidc_provider_arn / oidc_provider_url / namespace / service_account. false = use assume_role_policy_json."
  type        = bool
  default     = false
}

variable "create_inline_policy" {
  description = "Attach inline_policy_json to the role."
  type        = bool
  default     = false
}

