variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "repo-bridge-mcp-infra"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for document storage"
  type        = string
  default     = "repo-bridge-docs-dev"
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 1
}

variable "aurora_master_username" {
  description = "Aurora master username"
  type        = string
  default     = "postgres"
}

variable "lambda_reserved_concurrent_executions" {
  description = "Lambda reserved concurrent executions"
  type        = number
  default     = 50
}

variable "bedrock_embedding_model_arn" {
  description = "Bedrock embedding model ARN"
  type        = string
  default     = "arn:aws:bedrock:ap-northeast-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "api_key_parameter_name" {
  description = "Parameter Store path for API key"
  type        = string
  default     = "/repo-bridge-mcp-infra/dev/api-key"
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 30
}

variable "aurora_start_cron" {
  description = "Aurora start cron expression (UTC)"
  type        = string
  default     = "cron(0 0 * * ? *)" # 9:00 JST (00:00 UTC)
}

variable "aurora_stop_cron" {
  description = "Aurora stop cron expression (UTC)"
  type        = string
  default     = "cron(0 10 * * ? *)" # 19:00 JST (10:00 UTC)
}
