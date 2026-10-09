variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for SSE-KMS. Leave empty to use SSE-S3 (AES256)"
  type        = string
  default     = ""
}

variable "block_public_access" {
  description = "Block all public access to the bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow the bucket to be destroyed even if it still contains objects"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "List of lifecycle rule objects: { id, enabled, prefix, expiration_days, noncurrent_version_expiration_days, transitions = [{ days, storage_class }] }"
  type        = any
  default     = []
}

variable "tags" {
  description = "Common tags applied to the bucket"
  type        = map(string)
  default     = {}
}
