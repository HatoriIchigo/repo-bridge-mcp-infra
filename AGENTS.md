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
| docs/ | 設計ドキュメント（design.md等） |
| infra/ | Terraformインフラコード（API Gateway/Lambda/IAM等） |
| lambda/ | Lambda関数ソースコード（Python） |

## 技術スタック

- **IaC**: Terraform
- **Lambda Runtime**: Python 3.12
- **API Gateway**: REST API（APIキー認証）
- **RAG基盤**: Amazon Bedrock Knowledge Base
- **ストレージ**: Amazon S3
- **ログ・監視**: CloudWatch Logs, CloudWatch Metrics
- **リージョン**: ap-northeast-1（東京）

## コマンド

| コマンド | 用途 |
| --------- | ------ |
| `terraform -chdir=infra init` | Terraform初期化 |
| `terraform -chdir=infra plan` | 実行計画確認 |
| `terraform -chdir=infra apply` | インフラデプロイ |
| `terraform -chdir=infra destroy` | インフラ削除 |
| `cd lambda && pip install -r requirements.txt` | Lambda依存パッケージインストール |
| `pytest lambda/tests/` | Lambda関数テスト実行 |

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
