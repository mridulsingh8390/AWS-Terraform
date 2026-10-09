variable "cluster_id" {
  description = "ElastiCache cluster/replication group identifier"
  type        = string
}

variable "engine" {
  description = "Cache engine: redis or memcached"
  type        = string
  default     = "redis"

  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "engine must be either \"redis\" or \"memcached\"."
  }
}

variable "engine_version" {
  description = "Cache engine version"
  type        = string
}

variable "node_type" {
  description = "Cache node instance type, e.g. cache.t4g.medium"
  type        = string
}

variable "port" {
  description = "Port the cache engine listens on"
  type        = number
  default     = 6379
}

variable "subnet_ids" {
  description = "Subnet IDs for the cache subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs to attach"
  type        = list(string)
}

variable "parameter_group_name" {
  description = "Parameter group name override. Leave empty to use the engine default"
  type        = string
  default     = ""
}

# --- Redis-only ---

variable "cluster_mode_enabled" {
  description = "Enable Redis Cluster Mode (sharding). Redis only"
  type        = bool
  default     = false
}

variable "num_node_groups" {
  description = "Number of shards, when cluster_mode_enabled is true. Redis only"
  type        = number
  default     = 1
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard. Redis only"
  type        = number
  default     = 1
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ with automatic failover. Redis only"
  type        = bool
  default     = true
}

variable "at_rest_encryption_enabled" {
  description = "Encrypt data at rest. Redis only"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Encrypt data in transit. Redis only"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ARN for at-rest encryption. Redis only, leave empty for the AWS-managed default"
  type        = string
  default     = ""
}

variable "snapshot_retention_limit" {
  description = "Days to retain automatic snapshots. Redis only, 0 disables"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "Daily time range for snapshots. Redis only"
  type        = string
  default     = "03:00-05:00"
}

# --- Memcached-only ---

variable "num_cache_nodes" {
  description = "Number of cache nodes. Memcached only"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
