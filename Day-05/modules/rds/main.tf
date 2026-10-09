# =============================================================================
# COMMON MODULE: RDS
# Generic single RDS instance (Postgres/MySQL/etc). Uses AWS-managed master
# password in Secrets Manager by default instead of a plaintext var.
# =============================================================================

resource "aws_db_subnet_group" "this" {
  name       = "dbsubnet-${var.identifier}"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "dbsubnet-${var.identifier}"
  })
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type           = var.storage_type
  storage_encrypted      = true
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null

  db_name  = var.db_name != "" ? var.db_name : null
  username = var.username

  manage_master_user_password = var.manage_master_user_password
  password                    = var.manage_master_user_password ? null : var.password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  multi_az                = var.multi_az
  publicly_accessible     = false

  backup_retention_period = var.backup_retention_period
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window

  deletion_protection = var.deletion_protection
  skip_final_snapshot  = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final"

  performance_insights_enabled = var.performance_insights_enabled

  tags = merge(var.tags, {
    Name = var.identifier
  })
}
