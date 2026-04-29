# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-rag-handler"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-logs"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-api"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-api-gateway-logs"
  }
}

# CloudWatch Log Group for Aurora PostgreSQL
resource "aws_cloudwatch_log_group" "aurora" {
  name              = "/aws/rds/cluster/${var.project_name}-${var.environment}-kb/postgresql"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-logs"
  }
}
