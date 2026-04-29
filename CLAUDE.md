# CLAUDE.md

## プロジェクト概要

repo-bridge-mcpの裏側インフラとして、API Gateway + Lambda + Bedrock KB + S3で構成するMCP専用RAG基盤を管理するリポジトリ。
API Key制御で社内MCPからのみアクセス可能な検索・原本取得APIを提供する。
global/scope検索と全文取得（S3）を分離したハイブリッドRAG構成。

## ディレクトリ構成

| ディレクトリ | 説明 |
| -- | -- |
| .claude/ | Claude Code設定・ルール・スキル配置場所 |
| .context/ | コンテキストファイル配置場所 |
| docs/ | 設計ドキュメント（design.md, errors.md等） |
| infra/ | Terraformインフラコード |
| lambda/ | Lambda関数コード（SAM管理） |

## 技術スタック

- **IaC**: Terraform 1.5+
- **クラウド**: AWS ap-northeast-1
- **API**: API Gateway REST API
- **コンピュート**: Lambda Python 3.12
- **ベクトルDB**: Aurora PostgreSQL Serverless v2 (pgvector)
- **RAG基盤**: Bedrock Knowledge Base (Titan Embeddings v2)
- **ストレージ**: S3 Standard
- **認証**: API Gateway API Key (Usage Plan)
- **監視**: CloudWatch Logs/Metrics
- **スケジューラ**: EventBridge Scheduler

## コマンド

| コマンド | 用途 |
|---------|------|
| `cd infra && terraform init` | Terraform初期化 |
| `cd infra && terraform plan` | インフラ変更確認 |
| `cd infra && terraform apply` | インフラ適用 |
| `cd infra && terraform destroy` | インフラ削除 |
| `aws s3 cp <file> s3://repo-bridge-docs-dev/projects/<project_id>/` | S3へファイルアップロード |
| `aws bedrock-agent start-ingestion-job --knowledge-base-id <kb-id> --data-source-id <ds-id>` | Bedrock KB同期 |

## 応答原則

- 回答は全て日本語
- 体言止め・用言止めを使い、敬語・丁寧語は消去
- 「えーと」、「まあ」などのクッション言葉は禁止
- 情報水増しを禁止し、聞かれたことだけを回答する

## 行動原則

- 3ステップ以上のタスクは`Context Engineering`を取り入れる（コンテキストファイルの作成は`context-analyzer`エージェントを使用する）
- コンテキストファイル作成後は停止する。勝手に実装に入らない。
- 変更は必要な個所のみ、影響範囲を最小化する
- タスクの内容に応じ、`.claude/agents/` のエージェントを可能な範囲で活用する
