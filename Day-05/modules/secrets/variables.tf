variable "name_prefix" {
  type = string
}

variable "secret_names" {
  description = "Secret names (without the prefix) to create as empty containers."
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  type = string
}

variable "recovery_window_in_days" {
  description = "Days a deleted secret stays recoverable (0 = delete immediately; lab only, 7-30 for real environments)."
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
