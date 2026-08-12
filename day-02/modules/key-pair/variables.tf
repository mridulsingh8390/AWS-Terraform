variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
}

variable "output_path" {
  description = "Local path to save the generated .pem file"
  type        = string
  default     = "./"
}
