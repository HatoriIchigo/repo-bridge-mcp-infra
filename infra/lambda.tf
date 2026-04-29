# Lambda Security Group
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-role"
  }
}

# Lambda VPC Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda Custom Policy
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.project_name}-${var.environment}-lambda-custom-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate"
        ]
        Resource = aws_bedrockagent_knowledge_base.main.arn
      },
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
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.api_key_parameter_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-rag-handler:*"
      }
    ]
  })
}

# Lambda Function
# Note: デプロイパッケージはSAMで管理するため、ここではダミーコードで作成
resource "aws_lambda_function" "rag_handler" {
  filename         = "${path.module}/lambda_placeholder.zip"
  function_name    = "${var.project_name}-${var.environment}-rag-handler"
  role             = aws_iam_role.lambda.arn
  handler          = "main.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/lambda_placeholder.zip")
  runtime          = "python3.12"
  timeout          = 300
  memory_size      = 512

  reserved_concurrent_executions = var.lambda_reserved_concurrent_executions

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BEDROCK_KB_ID        = aws_bedrockagent_knowledge_base.main.id
      S3_BUCKET_NAME       = aws_s3_bucket.docs.id
      AURORA_CLUSTER_ARN   = aws_rds_cluster.knowledge_base.arn
      AURORA_SECRET_ARN    = aws_secretsmanager_secret.aurora_master.arn
      AURORA_DATABASE_NAME = aws_rds_cluster.knowledge_base.database_name
      API_KEY_PARAM_NAME   = var.api_key_parameter_name
      LOG_LEVEL            = "INFO"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rag-handler"
  }

  depends_on = [
    aws_iam_role_policy.lambda_custom,
    aws_iam_role_policy_attachment.lambda_vpc_execution
  ]

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      last_modified
    ]
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rag_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*/*"
}

# Create placeholder Lambda deployment package
resource "null_resource" "lambda_placeholder" {
  provisioner "local-exec" {
    command     = <<-EOT
      mkdir -p ${path.module}/tmp
      echo 'def lambda_handler(event, context): return {"statusCode": 200, "body": "Placeholder"}' > ${path.module}/tmp/main.py
      cd ${path.module}/tmp && zip -q ${path.module}/lambda_placeholder.zip main.py
      rm -rf ${path.module}/tmp
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }
}

# Ensure placeholder is created before Lambda
resource "null_resource" "lambda_dependency" {
  depends_on = [null_resource.lambda_placeholder]
}
