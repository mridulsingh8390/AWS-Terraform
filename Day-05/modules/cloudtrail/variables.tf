variable "name" {
  description = "Trail name (also the bucket name prefix)."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK for the trail and the bucket. Its key policy must allow cloudtrail.amazonaws.com (the kms module does)."
  type        = string
}

variable "expiration_days" {
  description = "Delete log objects after this many days. 0 = keep forever (use the client's retention policy)."
  type        = number
  default     = 0
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket. Lab/dev only."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
