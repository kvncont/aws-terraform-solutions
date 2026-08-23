###########################
##### S3 Files Bucket
###########################

resource "aws_s3_bucket" "this" {
  bucket        = "s3-${local.project_name}-${data.aws_caller_identity.current.account_id}-${var.deploy_region}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3files_file_system" "this" {
  depends_on = [aws_s3_bucket_versioning.this]

  bucket   = aws_s3_bucket.this.arn
  role_arn = aws_iam_role.s3files.arn
}

resource "aws_s3files_mount_target" "this" {
  count = local.create_subnets ? local.network_subnet_count : 0

  file_system_id  = aws_s3files_file_system.this.id
  subnet_id       = aws_subnet.eks[count.index].id
  security_groups = [aws_security_group.efs.id]
}