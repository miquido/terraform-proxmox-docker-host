# WAL-G backups of the databases of the deployed stacks. The host reaches the bucket with the same Roles Anywhere
# identity as for DNS-01 (roles_anywhere.tf), so there is no IAM user and no access key: walg_env_vars below only point
# the AWS SDK at the profile in /roles-anywhere/config. The compose project has to mount
# /home/ubuntu/aws-roles-anywhere at /roles-anywhere (read-only) into the containers that run wal-g, and choose the
# bucket itself (WALG_S3_PREFIX, usually from a CI variable): the bucket here is only what the role may use.
resource "aws_s3_bucket" "walg" {
  bucket = "${var.name}-walg-backups"
}

resource "aws_s3_bucket_public_access_block" "walg" {
  bucket = aws_s3_bucket.walg.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "walg" {
  bucket = aws_s3_bucket.walg.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "walg" {
  bucket = aws_s3_bucket.walg.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_iam_role_policy" "walg" {
  name = "walg-s3"
  role = aws_iam_role.dns_challenge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.walg.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.walg.arn
      },
    ]
  })
}
