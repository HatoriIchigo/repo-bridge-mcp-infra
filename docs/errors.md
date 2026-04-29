# エラーレスポンス仕様

## エラーレスポンス基本形式

全APIエンドポイントで統一されたエラーレスポンス形式を使用する。

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "エラーメッセージ（日本語）"
  }
}
```

---

## エラーコード一覧

### 4xx クライアントエラー

| HTTPステータス | code | 説明 | 発生条件 |
|---------------|------|------|---------|
| 400 | INVALID_MODE | modeパラメータが不正 | `mode`が`global`/`scoped`以外 |
| 400 | INVALID_PARAMETER | 必須パラメータ不足または形式エラー | `scoped_search`で`project_id`なし、`top_k`が範囲外など |
| 400 | INVALID_S3_KEY | S3キー形式が不正 | `fetch`の`s3_key`がS3オブジェクトキー形式に準拠していない |
| 401 | UNAUTHORIZED | API Key認証失敗 | `x-api-key`ヘッダーなし、または無効なAPIキー |
| 403 | FORBIDDEN | アクセス権限なし | APIキーが有効だがリソースへのアクセス権限がない |
| 404 | NOT_FOUND | ドキュメントが存在しない | 指定された`s3_key`に対応するドキュメントがS3に存在しない |

### 5xx サーバーエラー

| HTTPステータス | code | 説明 | 発生条件 |
|---------------|------|------|---------|
| 500 | INTERNAL_ERROR | サーバー内部エラー | Lambda実行時の予期しないエラー |
| 502 | BEDROCK_KB_ERROR | Bedrock KB接続エラー | Bedrock Knowledge Base APIへのリクエストが失敗 |
| 500 | PRESIGNED_URL_GENERATION_FAILED | Presigned URL生成失敗 | S3署名付きURL生成時のエラー（IAM権限不足等） |
| 504 | BEDROCK_KB_TIMEOUT | Bedrock KBタイムアウト | Bedrock Knowledge Base APIのレスポンスが30秒以内に返却されない |

---

## エラーレスポンス例

### INVALID_PARAMETER

```json
{
  "error": {
    "code": "INVALID_PARAMETER",
    "message": "project_idが指定されていません"
  }
}
```

### INVALID_S3_KEY

```json
{
  "error": {
    "code": "INVALID_S3_KEY",
    "message": "s3_keyの形式が不正です: expected format 'project_id/file_name'"
  }
}
```

### PRESIGNED_URL_GENERATION_FAILED

```json
{
  "error": {
    "code": "PRESIGNED_URL_GENERATION_FAILED",
    "message": "S3署名付きURLの生成に失敗しました"
  }
}
```

### BEDROCK_KB_ERROR

```json
{
  "error": {
    "code": "BEDROCK_KB_ERROR",
    "message": "Bedrock Knowledge Baseへの接続に失敗しました"
  }
}
```

### BEDROCK_KB_TIMEOUT

```json
{
  "error": {
    "code": "BEDROCK_KB_TIMEOUT",
    "message": "Bedrock Knowledge Baseのレスポンスがタイムアウトしました"
  }
}
```

---

## エラーハンドリング方針

### クライアント側の推奨対応

| エラー種別 | 推奨対応 |
|-----------|---------|
| 4xx（クライアントエラー） | リクエストパラメータを修正して再送信 |
| 401/403（認証・認可エラー） | APIキーを確認、再認証 |
| 5xx（サーバーエラー） | リトライ |
