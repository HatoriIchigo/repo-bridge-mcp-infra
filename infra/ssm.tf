# Parameter Store for API Key
# Note: 実際のAPIキー値は手動で設定する必要がある
resource "aws_ssm_parameter" "api_key" {
  name        = var.api_key_parameter_name
  description = "API key for repo-bridge-mcp clients"
  type        = "SecureString"
  value       = "PLACEHOLDER_CHANGE_ME" # デプロイ後に手動で変更

  tags = {
    Name = "${var.project_name}-${var.environment}-api-key"
  }

  lifecycle {
    ignore_changes = [value]
  }
}
