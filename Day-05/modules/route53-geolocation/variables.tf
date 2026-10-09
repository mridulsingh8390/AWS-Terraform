variable "hosted_zone_id" {
  description = "Route 53 hosted zone that owns the record (supplied by Securus)."
  type        = string
}

variable "domain_name" {
  description = "Record name, e.g. rtc.example.com (supplied by Securus)."
  type        = string
}

variable "set_identifier" {
  description = "Unique identifier for this routing record, e.g. use1 / usw2."
  type        = string
}

# At least one of continent / country must be set. A single continent can only
# be mapped to ONE record, so an east/west split inside the US needs
# country = "US" + subdivision = "<state code>" records (one per state group),
# plus a default record with country = "*".
variable "continent" {
  description = "Continent code (AF, AN, AS, EU, OC, NA, SA). Leave null when using country/subdivision."
  type        = string
  default     = null
}

variable "country" {
  description = "ISO 3166-1 alpha-2 country code, or \"*\" for the default record."
  type        = string
  default     = null
}

variable "subdivision" {
  description = "US state code (e.g. VA, CA). Only valid together with country = \"US\"."
  type        = string
  default     = null
}

variable "alb_dns_name" {
  description = "DNS name of the regional ALB/NLB for this record."
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the regional load balancer (alias target)."
  type        = string
}

variable "health_check_path" {
  description = "HTTPS path probed by the Route 53 health check."
  type        = string
  default     = "/health"
}

variable "tags" {
  type    = map(string)
  default = {}
}
