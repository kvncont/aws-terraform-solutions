# =============================================================================
# Bucket S3 para el Truststore de mTLS
# El truststore contiene el certificado de la CA del cliente (client-ca.crt)
# API Gateway lo usa para validar los certificados de los clientes.
# =============================================================================

resource "aws_s3_bucket" "truststore" {
  bucket = "${var.project_name}-truststore-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-truststore"
    Purpose = "mTLS Truststore"
  }
}

# Bloquear todo acceso público
resource "aws_s3_bucket_public_access_block" "truststore" {
  bucket = aws_s3_bucket.truststore.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionado: permite a API Gateway referenciar versiones específicas del truststore
resource "aws_s3_bucket_versioning" "truststore" {
  bucket = aws_s3_bucket.truststore.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo
resource "aws_s3_bucket_server_side_encryption_configuration" "truststore" {
  bucket = aws_s3_bucket.truststore.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Política: solo la cuenta propietaria puede acceder
resource "aws_s3_bucket_policy" "truststore" {
  bucket = aws_s3_bucket.truststore.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.truststore.arn,
          "${aws_s3_bucket.truststore.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowAPIGatewayRead"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.truststore.arn}/${var.truststore_s3_key}"
      }
    ]
  })
}

# Subir el truststore generado localmente con el script generate_certs.sh
resource "aws_s3_object" "truststore_pem" {
  bucket = aws_s3_bucket.truststore.id
  key    = var.truststore_s3_key
  source = "${path.module}/certs/truststore.pem"
  etag   = filemd5("${path.module}/certs/truststore.pem")

  tags = {
    Name = "mTLS Truststore"
  }
}

# Data source para obtener el account ID
data "aws_caller_identity" "current" {}
