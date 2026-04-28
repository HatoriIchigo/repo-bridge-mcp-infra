# design.md

## 1. 概要（Overview）

repo-bridge-mcpの裏側インフラとして、Bedrock Knowledge BaseとS3を活用したハイブリッドRAG基盤を提供する。
API Gateway + Lambdaで構成し、APIキー認証により社内MCPからのみアクセス可能なRAG検索・原本取得APIを提供する。
global/scope検索の2種類のRAG検索と、S3からの全文取得を分離することで、効率的な情報検索を実現する。

---

## 2. アーキテクチャ設計

```mermaid
graph LR
    MCP[社内MCP Client] -->|API Key認証| APIGW[API Gateway]
    APIGW -->|全エンドポイント| Lambda[Lambda Function]

    Lambda -->|mode=semantic_search| KB[Bedrock Knowledge Base]
    Lambda -->|mode=scoped_search<br/>メタデータフィルタ適用| KB
    Lambda -->|mode=fetch| S3Data[(S3 Bucket)]

    KB -->|ベクトル検索| VectorDB[(Vector Store)]
    KB -->|メタデータ参照| S3Data

    subgraph AWS
        APIGW
        Lambda
        KB
        VectorDB
        S3Data
    end
```

### コンポーネント構成

| コンポーネント | 役割 |
|--------------|------|
| API Gateway | APIキー認証・エンドポイント管理 |
| Lambda Function | 統合ハンドラ（検索/取得を内部で条件分岐） |
| Bedrock Knowledge Base | RAG検索エンジン |
| Vector Store | ベクトルデータストア（Bedrock KB内部） |
| S3 Bucket | ドキュメント原本ストレージ |

### データの流れ

1. **意味検索フロー（semantic_search）**: MCP → API Gateway → Lambda（mode判定） → Bedrock KB → レスポンス
2. **スコープ限定検索フロー（scoped_search）**: MCP → API Gateway → Lambda（mode判定 + メタデータフィルタ） → Bedrock KB → レスポンス
3. **全文取得フロー（fetch）**:
   - MCP → API Gateway → Lambda（mode判定） → S3 Presigned URL生成（有効期限5分） → URL返却
   - MCP → S3（Presigned URL直接アクセス） → ファイルダウンロード

---

## 3. 機能一覧

| 機能ID | 機能名 | 優先度 | 概要 |
|--------|--------|--------|------|
| F-001 | 意味検索（semantic_search） | 高 | Bedrock KBを使用した全体意味検索 |
| F-002 | スコープ限定検索（scoped_search） | 高 | メタデータフィルタ + Bedrock KBによる検索 |
| F-003 | 全文取得（fetch） | 高 | S3から原本ドキュメント全文を取得 |
| F-004 | APIキー認証 | 高 | API Gateway usage planによる認証 |
| F-005 | メタデータ管理 | 中 | project_id/type/system/tagsによる分類 |

---

## 4. API設計

### 4.1 エンドポイント一覧

| メソッド | パス | 概要 |
|---------|------|------|
| POST | `/rag/query` | 統合エンドポイント（modeパラメータで分岐） |

**modeパラメータ**:
- `semantic_search`: 意味検索（global、Bedrock KB使用）
- `scoped_search`: スコープ限定検索（メタデータ絞り込み + KB併用）
- `fetch`: 全文取得（S3 GetObject）

### 4.2 認証方式

- **APIキー認証**: `x-api-key`ヘッダーによるAPI Gateway usage plan認証
- 社内MCP専用のAPIキーを発行

### 4.3 リクエストIF（共通形式）

#### 基本形

```json
{
  "mode": "semantic_search | scoped_search | fetch",
  "query": "検索クエリ文字列（modeがfetchの場合は不要）",
  "s3_key": "S3オブジェクトキー（modeがfetchの場合のみ必須）",
  "scope": {
    "project_id": "プロジェクトID（scoped_searchの場合のみ必須）"
  },
  "options": {
    "top_k": 5,
    "include_content": false
  }
}
```

### 4.4 各モード詳細

#### 4.4.1 semantic_search（意味検索）

**用途**: 全プロジェクト横断で意味的に類似したドキュメントを検索

**リクエスト例**:
```json
{
  "mode": "semantic_search",
  "query": "似た案件のAPI仕様はある？",
  "options": {
    "top_k": 5
  }
}
```

**処理フロー**: Lambda → Bedrock KB（プロジェクトフィルタなし）

**レスポンス（200 OK）**:
```json
{
  "mode": "semantic_search",
  "results": [
    {
      "s3_key": "projects/billing-system/docs/spec/v2/api-spec.md",
      "title": "API仕様書 v1.2",
      "score": 0.87,
      "snippet": "...検索結果の抜粋テキスト...",
      "metadata": {
        "project_id": "billing-system",
        "format": "markdown",
        "size": 10240,
        "last_updated": "2026-04-28T12:00:00Z"
      }
    }
  ],
  "source": "bedrock",
  "metadata": {
    "total": 12,
    "query_time_ms": 234
  }
}
```

#### 4.4.2 scoped_search（スコープ限定検索）

**用途**: 特定プロジェクト内のドキュメントを検索

**リクエスト例**:
```json
{
  "mode": "scoped_search",
  "query": "IF仕様書",
  "scope": {
    "project_id": "billing-system"
  },
  "options": {
    "top_k": 5
  }
}
```

**処理フロー**: Lambda → project_idフィルタ適用 → Bedrock KB

**レスポンス（200 OK）**: semantic_searchと同一形式

#### 4.4.3 fetch（全文取得）

**用途**: ドキュメント全文をS3から取得

**リクエスト例**:
```json
{
  "mode": "fetch",
  "s3_key": "projects/billing-system/docs/spec/v2/api-spec.md"
}
```

**処理フロー**: Lambda → S3 Presigned URL生成（有効期限300秒）

**レスポンス（200 OK）**:
```json
{
  "mode": "fetch",
  "s3_key": "projects/billing-system/docs/spec/v2/api-spec.md",
  "download_url": "https://bucket-name.s3.ap-northeast-1.amazonaws.com/path/to/api-spec.md?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=...&X-Amz-Signature=...",
  "expires_in": 300,
  "metadata": {
    "title": "API仕様書 v1.2",
    "project_id": "billing-system",
    "format": "markdown",
    "size": 10240,
    "last_updated": "2026-04-28T12:00:00Z"
  }
}
```

**レスポンスフィールド説明**:

- `download_url`: S3 Presigned URL（署名付き、5分間有効）
- `expires_in`: URL有効期限（秒、デフォルト300秒）
- `metadata.format`: ファイル形式（markdown/txt/pdf等）

### 4.5 scope設計（メタデータ構造）

**scopeオブジェクトの構造**:

```json
{
  "project_id": "billing-system"
}
```

**フィールド仕様**:

| フィールド | 型 | 必須 | 説明 | 例 |
|-----------|-----|-----|------|-----|
| project_id | string | Yes（scoped_searchのみ） | プロジェクト識別子 | "billing-system", "auth-platform" |

**scoped_searchの用途**:

- 特定プロジェクト内のドキュメントに検索範囲を限定
- プロジェクト横断検索は`semantic_search`を使用
- Bedrock KBのメタデータフィルタリング機能（`project_id`のみ）を活用

### 4.6 Lambda内部ルーティングルール

```python
if mode == "semantic_search":
    # メタデータフィルタなしでBedrock KBを呼び出し
    → bedrock_kb.retrieve(query, filter=None)

elif mode == "scoped_search":
    # scopeからメタデータフィルタを構築（project_idのみ）
    metadata_filter = {"equals": {"key": "project_id", "value": scope["project_id"]}}
    → bedrock_kb.retrieve(query, filter=metadata_filter)

elif mode == "fetch":
    # s3_keyを使用して直接Presigned URL生成
    → s3.generate_presigned_url('get_object', Params={'Bucket': bucket, 'Key': s3_key}, ExpiresIn=300)

else:
    → HTTP 400 INVALID_MODE
```

**ルーティング判定フロー**:

```mermaid
graph TD
    START[リクエスト受信] --> VALIDATE{mode検証}
    VALIDATE -->|semantic_search| SEMANTIC[Bedrock KB<br/>フィルタなし]
    VALIDATE -->|scoped_search| SCOPE[メタデータフィルタ構築]
    VALIDATE -->|fetch| FETCH[S3キー解決]
    VALIDATE -->|不正| ERROR[400 INVALID_MODE]

    SCOPE --> BEDROCK[Bedrock KB<br/>フィルタ適用]
    FETCH --> S3[S3 GetObject]

    SEMANTIC --> RESPONSE[レスポンス生成]
    BEDROCK --> RESPONSE
    S3 --> RESPONSE
    ERROR --> RESPONSE
```

### 4.7 エラーレスポンス

```json
{
  "error": {
    "code": "INVALID_MODE | NOT_FOUND | UNAUTHORIZED | INTERNAL_ERROR",
    "message": "エラーメッセージ"
  }
}
```

| HTTPステータス | code | 説明 |
|---------------|------|------|
| 400 | INVALID_MODE | modeパラメータが不正 |
| 404 | NOT_FOUND | ドキュメントが存在しない |
| 403 | UNAUTHORIZED | 認証エラー |
| 500 | INTERNAL_ERROR | サーバーエラー |

---

## 5. データモデル

```mermaid
erDiagram
    DOCUMENT ||--o{ VECTOR_EMBEDDING : has
    DOCUMENT ||--|| S3_OBJECT : stored_as

    DOCUMENT {
        string document_id PK
        string file_path
        string scope
        timestamp last_updated
        json metadata
    }

    VECTOR_EMBEDDING {
        string embedding_id PK
        string document_id FK
        vector embedding_vector
        string chunk_text
    }

    S3_OBJECT {
        string s3_key PK
        string document_id FK
        string bucket_name
        int file_size
    }
```

### エンティティ説明

| エンティティ | 説明 |
|------------|------|
| DOCUMENT | ドキュメントメタデータ（Bedrock KB管理） |
| VECTOR_EMBEDDING | ベクトル埋め込み（Bedrock KB内部） |
| S3_OBJECT | S3格納ファイル情報 |

### 5.1 S3バケット構造

プロジェクトベースの階層構造を採用。既存プロジェクトのディレクトリ構造をそのままアップロード可能。

```
s3://repo-bridge-docs/
├── projects/
│   ├── {project_id}/
│   │   └── {既存プロジェクトのディレクトリ構造}
│   └── ...
└── _metadata/
    └── index.json
```

**ディレクトリ説明**:

| パス | 説明 |
|------|------|
| `projects/{project_id}/` | プロジェクトごとのルートディレクトリ |
| `projects/{project_id}/*` | 既存プロジェクトのディレクトリ構造（階層深度制限なし） |
| `_metadata/` | メタデータ管理用（将来拡張用） |

**具体例**:

```
s3://repo-bridge-docs/
├── projects/
│   ├── billing-system/
│   │   └── docs/
│   │       ├── design/
│   │       │   └── system-design.md
│   │       ├── spec/
│   │       │   ├── v1/
│   │       │   │   └── requirement.md
│   │       │   └── v2/
│   │       │       └── api-spec.md
│   │       └── memo/
│   │           └── 2026/
│   │               └── 04/
│   │                   └── meeting-20260428.md
│   └── auth-platform/
│       └── docs/
│           └── spec/
│               └── initial-requirement.md
```

**特徴**:
- 階層深度に制限なし（S3のオブジェクトストレージ特性を活用）
- 既存プロジェクトのディレクトリ構造を変更せずアップロード可能
- `s3_key`はメタデータで管理し、階層構造に依存しない設計

### 5.2 メタデータ管理

Bedrock KBメタデータに以下を格納:

```json
{
  "metadataAttributes": {
    "project_id": "billing-system",
    "s3_key": "projects/billing-system/docs/spec/v2/api-spec.md",
    "title": "API仕様書 v1.2",
    "format": "markdown",
    "size": 10240,
    "last_updated": "2026-04-28T12:00:00Z"
  }
}
```

**フィールド説明**:

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|-----|------|
| project_id | string | Yes | プロジェクト識別子（scoped_searchフィルタ用） |
| s3_key | string | Yes | S3オブジェクトキー（一意識別子・fetch用） |
| title | string | Yes | ドキュメントタイトル |
| format | string | Yes | ファイル形式（markdown/txt/pdf等） |
| size | number | Yes | ファイルサイズ（バイト） |
| last_updated | string | Yes | 最終更新日時（ISO 8601形式） |

**fetch処理フロー**:

1. MCPクライアントが検索結果から`s3_key`を取得
2. `s3_key`を指定してfetchリクエスト
3. Lambda関数が`s3_key`を使用して直接Presigned URL生成

---

## 6. 非機能要件

### 6.1 パフォーマンス

| 項目 | 目標値 |
|------|--------|
| 検索レスポンスタイム（95パーセンタイル） | 2秒以内 |
| ファイル取得レスポンスタイム（1MB以下） | 1秒以内 |
| 同時リクエスト処理数 | 100リクエスト/秒 |

### 6.2 セキュリティ

| 項目 | 要件 |
|------|------|
| 認証方式 | API Gateway APIキー認証 |
| 通信暗号化 | TLS 1.2以上 |
| アクセス制御 | 社内MCP専用APIキーのみ許可 |
| ログ保管 | CloudWatch Logsに30日間保管 |

### 6.3 可用性

| 項目 | 目標値 |
|------|--------|
| SLA | 99.9% |
| Lambda同時実行数 | 予約済み同時実行数: 50 |
| S3可用性 | Standard（99.99%） |

### 6.4 スケーラビリティ

- Lambda: 自動スケーリング（最大1000同時実行）
- API Gateway: 制限なし（usage planでスロットリング設定）
- Bedrock KB: マネージドサービスによる自動スケール

---

## 7. 制約・前提条件

### 7.1 スコープ内

- RAG検索機能（global/scope）
- S3からのファイル取得機能
- APIキー認証

### 7.2 スコープ外

- ユーザー管理機能
- ファイルアップロード機能（別リポジトリで管理）
- フロントエンドUI
- リアルタイム更新通知

### 7.3 前提条件

- S3 Bucketが作成済み（別途手動作成または別リポジトリで管理）
- Bedrockモデルアクセス権限が有効
- AWSアカウントにAPI Gateway・Lambda・Bedrock実行権限がある
- Terraformバックエンド（S3 + DynamoDB）が構成済み

### 7.4 技術的制約

- リージョン: ap-northeast-1（東京）
- Lambda実行時間: 最大15分（ただし検索は2秒以内を目標）
- API Gatewayペイロード上限: 10MB
- Bedrock KB最大ドキュメント数: 100万件（要確認）

---

## 8. 技術スタック

| カテゴリ | 技術 |
|---------|------|
| IaC | Terraform |
| Lambda Runtime | Python 3.12 |
| API Gateway | REST API（APIキー認証） |
| RAG基盤 | Amazon Bedrock Knowledge Base |
| ストレージ | Amazon S3 |
| ログ・監視 | CloudWatch Logs, CloudWatch Metrics |
| デプロイ | Terraform apply |

---

## 9. 運用・監視

### 9.1 監視項目

| 項目 | メトリクス | アラート閾値 |
|------|----------|-------------|
| API Gateway 4xx率 | 4XXError | 5%以上 |
| API Gateway 5xx率 | 5XXError | 1%以上 |
| Lambda エラー率 | Errors | 1%以上 |
| Lambda実行時間 | Duration | 2000ms超過 |
| S3アクセスエラー | 4XXError | 10件/分以上 |

### 9.2 ログ出力

- API Gateway: アクセスログ（CloudWatch Logs）
- Lambda: 構造化ログ（JSON形式、INFO/ERROR）
- Bedrock KB: クエリログ（CloudWatch Logs）

---

## 10. デプロイ戦略

### 10.1 環境

| 環境 | 用途 |
|------|------|
| dev | 開発環境（検証・本番兼用） |

### 10.2 デプロイフロー

```mermaid
graph LR
    CODE[コード変更] --> CI[CI/CD Pipeline]
    CI --> TEST[テスト実行]
    TEST --> DEV[dev環境デプロイ]
```

### 10.3 ロールバック戦略

- Lambda: エイリアス・バージョン管理による即時ロールバック
- API Gateway: ステージ切り替えによるロールバック
- IaC: Terraformステート履歴による復元

### 10.4 API Key管理

- **管理方式**: AWS Systems Manager Parameter Store（SecureString）
- **配置**: `/repo-bridge-mcp-infra/dev/api-key`
- **アクセス制御**: IAMポリシーによる制限
- **ローテーション**: 手動更新（必要に応じてSecrets Managerへ移行可）

### 10.5 インフラ管理方針

- **インフラコード配置**: `infra/` ディレクトリ
- **管理対象**: API Gateway、Lambda、Parameter Store、IAM Role等
- **管理対象外**: S3 Bucket（別途手動作成または別リポジトリで管理）
