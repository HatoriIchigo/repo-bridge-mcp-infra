terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # バックエンド設定はterraform initで指定
    # terraform init -backend-config="bucket=<tfstate-bucket>" \
    #                -backend-config="key=repo-bridge-mcp-infra/terraform.tfstate" \
    #                -backend-config="region=ap-northeast-1" \
    #                -backend-config="dynamodb_table=<lock-table>"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "repo-bridge-mcp-infra"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
