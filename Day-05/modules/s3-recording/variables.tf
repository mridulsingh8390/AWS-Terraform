variable "bucket_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "retention_days" {
  description = "Default Object Lock retention in days."
  type        = number
  default     = 2555
}

variable "object_lock_mode" {
  description = "GOVERNANCE (privileged users can bypass; safe for dev/qa) or COMPLIANCE (immutable for everyone, including root). Use COMPLIANCE only after Securus confirms the retention policy."
  type        = string
  default     = "GOVERNANCE"

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE."
  }
}

variable "lifecycle_transition_days" {
  type    = number
  default = 90
}

variable "lifecycle_expiration_days" {
  type    = number
  default = 0
}

variable "tags" {
  type    = map(string)
  default = {}
}
