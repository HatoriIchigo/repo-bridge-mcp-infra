output "s3_bucket_name" {
  description = "S3 bucket name for document storage"
  value       = aws_s3_bucket.docs.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.docs.arn
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.knowledge_base.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.knowledge_base.reader_endpoint
}

output "aurora_cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.knowledge_base.arn
}

output "bedrock_kb_id" {
  description = "Bedrock Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "bedrock_kb_arn" {
  description = "Bedrock Knowledge Base ARN"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = "${aws_api_gateway_deployment.main.invoke_url}${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.rag_handler.arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.rag_handler.function_name
}

output "api_key_parameter_name" {
  description = "API Key parameter store path"
  value       = aws_ssm_parameter.api_key.name
}

output "api_gateway_api_key_value" {
  description = "API Gateway API Key value"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

output "aurora_master_password_secret_arn" {
  description = "Aurora master password secret ARN"
  value       = aws_secretsmanager_secret.aurora_master.arn
}
