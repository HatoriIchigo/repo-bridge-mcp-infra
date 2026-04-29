# S3 Bucket for document storage
resource "aws_s3_bucket" "docs" {
  bucket = var.s3_bucket_name

  tags = {
    Name = var.s3_bucket_name
  }
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy for Bedrock Knowledge Base access
resource "aws_s3_bucket_policy" "docs" {
  bucket = aws_s3_bucket.docs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBedrockKnowledgeBaseRead"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.docs.arn,
          "${aws_s3_bucket.docs.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Current AWS account ID
data "aws_caller_identity" "current" {}
