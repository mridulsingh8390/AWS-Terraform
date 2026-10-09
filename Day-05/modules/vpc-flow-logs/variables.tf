variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "kms_key_arn" {
  description = "CMK used to encrypt the log group. Its key policy must allow the CloudWatch Logs service (the kms module does)."
  type        = string
}

variable "retention_days" {
  description = "CloudWatch retention in days. Must be a value CloudWatch accepts (e.g. 30, 90, 365, 731, 1827, 3653)."
  type        = number
  default     = 365
}

variable "tags" {
  type    = map(string)
  default = {}
}
