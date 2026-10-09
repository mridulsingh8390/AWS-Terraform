output "primary_endpoint" {
  description = "Primary/configuration endpoint address"
  value       = var.engine == "redis" ? try(aws_elasticache_replication_group.redis[0].primary_endpoint_address, null) : try(aws_elasticache_cluster.memcached[0].configuration_endpoint, null)
}

output "reader_endpoint" {
  description = "Reader endpoint address (Redis only, non-cluster-mode)"
  value       = try(aws_elasticache_replication_group.redis[0].reader_endpoint_address, null)
}

output "port" {
  description = "Port the cache engine listens on"
  value       = var.port
}

output "arn" {
  description = "ARN of the cache cluster/replication group"
  value       = var.engine == "redis" ? try(aws_elasticache_replication_group.redis[0].arn, null) : try(aws_elasticache_cluster.memcached[0].arn, null)
}
