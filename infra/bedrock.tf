# IAM Role for Bedrock Knowledge Base
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-bedrock-kb-role"
  }
}

# IAM Policy for Bedrock KB to access S3
resource "aws_iam_role_policy" "bedrock_kb_s3" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-s3-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.docs.arn,
          "${aws_s3_bucket.docs.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for Bedrock KB to access Aurora
resource "aws_iam_role_policy" "bedrock_kb_rds" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-rds-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = aws_rds_cluster.knowledge_base.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.aurora_master.arn
      }
    ]
  })
}

# IAM Policy for Bedrock KB to invoke foundation models
resource "aws_iam_role_policy" "bedrock_kb_model" {
  name = "${var.project_name}-${var.environment}-bedrock-kb-model-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = var.bedrock_embedding_model_arn
      }
    ]
  })
}

# Bedrock Knowledge Base
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-${var.environment}-kb"
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.bedrock_embedding_model_arn
    }
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = aws_secretsmanager_secret.aurora_master.arn
      database_name          = aws_rds_cluster.knowledge_base.database_name
      resource_arn           = aws_rds_cluster.knowledge_base.arn
      table_name             = "bedrock_integration.bedrock_kb"

      field_mapping {
        metadata_field     = "metadata"
        primary_key_field  = "id"
        text_field         = "chunks"
        vector_field       = "embedding"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-kb"
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_s3,
    aws_iam_role_policy.bedrock_kb_rds,
    aws_iam_role_policy.bedrock_kb_model,
    aws_rds_cluster_instance.knowledge_base
  ]
}

# Bedrock Knowledge Base Data Source
resource "aws_bedrockagent_data_source" "s3_docs" {
  name              = "${var.project_name}-${var.environment}-s3-docs"
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.docs.arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}
