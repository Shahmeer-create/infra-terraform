# ---------------------------------------------------------------------------
# S3 — Photos bucket
# Private, encrypted, versioned, HTTPS-only, lifecycle to Standard-IA
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "photos" {
  bucket = "${local.name_prefix}-photos-${data.aws_caller_identity.current.account_id}"

  force_destroy = !var.enable_deletion_protection

  tags = {
    Name = "${local.name_prefix}-photos"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "photos" {
  bucket = aws_s3_bucket.photos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "photos" {
  bucket = aws_s3_bucket.photos.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rule — transition to Standard-IA after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Bucket policy: deny all non-HTTPS requests
data "aws_iam_policy_document" "photos_bucket_policy" {
  statement {
    sid    = "DenyNonHTTPS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.photos.arn,
      "${aws_s3_bucket.photos.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "photos" {
  bucket     = aws_s3_bucket.photos.id
  policy     = data.aws_iam_policy_document.photos_bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.photos]
}
