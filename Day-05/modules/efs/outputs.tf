output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.postgres.id
}

output "efs_arn" {
  value = aws_efs_file_system.postgres.arn
}

output "access_point_id" {
  description = "EFS access point ID for the PostgreSQL directory"
  value       = aws_efs_access_point.postgres.id
}

output "storageclass_manifest_path" {
  description = "Path to the written Kubernetes StorageClass YAML"
  value       = local_file.storageclass.filename
}
