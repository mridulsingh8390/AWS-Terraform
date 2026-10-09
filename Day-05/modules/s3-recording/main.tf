################################################################################
# Dragonfly LiveKit HLS recording bucket
# Object Lock is enabled at bucket creation. The lock mode is a variable
# (default GOVERNANCE). Switch prod to COMPLIANCE only after Securus confirms
# the retention / legal-hold policy, because COMPLIANCE retention is immutable.
################################################################################

resource "aws_s3_bucket" "recordings" {
  bucket              = var.bucket_name
  object_lock_enabled = true

  tags = merge(var.tags, {
    Name       = var.bucket_name
    DataClass  = "Restricted"
    Workload   = "LiveKit-Recording"
    Compliance = "CJIS"
  })
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket                  = aws_s3_bucket.recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.recordings]
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    id     = "archive-recordings"
    status = "Enabled"
    filter { prefix = "" }

    transition {
      days          = var.lifecycle_transition_days
      storage_class = "GLACIER"
    }

    dynamic "expiration" {
      for_each = var.lifecycle_expiration_days > 0 ? [1] : []
      content { days = var.lifecycle_expiration_days }
    }
  }
}

# TLS-only access (CJIS / FIPS transport requirement). Applied after the public
# access block so the two S3 API calls do not race each other.
resource "aws_s3_bucket_policy" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.recordings.arn,
        "${aws_s3_bucket.recordings.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.recordings]
}
