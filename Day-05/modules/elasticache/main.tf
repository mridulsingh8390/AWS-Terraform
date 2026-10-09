# =============================================================================
# COMMON MODULE: ELASTICACHE
# Generic Redis replication group (default) or Memcached cluster.
# =============================================================================

resource "aws_elasticache_subnet_group" "this" {
  name       = "cache-subnet-${var.cluster_id}"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

resource "aws_elasticache_replication_group" "redis" {
  count = var.engine == "redis" ? 1 : 0

  replication_group_id = var.cluster_id
  description           = "Redis replication group for ${var.cluster_id}"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port

  num_node_groups         = var.cluster_mode_enabled ? var.num_node_groups : 1
  replicas_per_node_group = var.cluster_mode_enabled ? var.replicas_per_node_group : var.replicas_per_node_group
  automatic_failover_enabled = var.replicas_per_node_group > 0 || var.cluster_mode_enabled
  multi_az_enabled           = var.multi_az_enabled

  subnet_group_name = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  kms_key_id                  = var.kms_key_id != "" ? var.kms_key_id : null

  parameter_group_name = var.parameter_group_name != "" ? var.parameter_group_name : null

  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window

  tags = merge(var.tags, {
    Name = var.cluster_id
  })
}

resource "aws_elasticache_cluster" "memcached" {
  count = var.engine == "memcached" ? 1 : 0

  cluster_id     = var.cluster_id
  engine         = "memcached"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = var.port
  num_cache_nodes = var.num_cache_nodes

  subnet_group_name = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  parameter_group_name = var.parameter_group_name != "" ? var.parameter_group_name : null

  tags = merge(var.tags, {
    Name = var.cluster_id
  })
}
