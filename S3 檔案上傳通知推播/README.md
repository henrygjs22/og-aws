# S3 圖片上傳 → Discord 通知（Terraform + Lambda）

圖片上傳到 S3 bucket 時，由 Lambda 觸發並發送通知到 Discord Webhook。

## 架構

- **S3 Bucket**：存放上傳的圖片
- **Lambda**：收到 S3 `ObjectCreated` 事件後，組訊息並 POST 到 Discord Webhook
- **觸發條件**：副檔名為 `.jpg`、`.jpeg`、`.png`、`.gif`、`.webp` 的物件建立時

## 使用方式

1. 複製變數範例並填入 Discord Webhook URL：
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # 編輯 terraform.tfvars，設定 discord_webhook_url
   ```

2. 初始化與部署：
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. 測試上傳（需已設定 AWS CLI 認證）：
   ```bash
   aws s3 cp 你的圖片.png s3://<bucket_name>/
   ```
   上傳後 Discord 頻道應會收到通知。

## 變數說明

| 變數 | 說明 | 必填 |
|------|------|------|
| `discord_webhook_url` | Discord Webhook URL | 是 |
| `aws_region` | AWS 區域 | 否（預設 ap-northeast-1） |
| `project_name` | 專案名稱，用於資源命名 | 否 |

## 注意事項

- `discord_webhook_url` 請勿提交到版控，使用 `terraform.tfvars` 並確保已加入 `.gitignore`。
- S3 bucket 名稱為 `{project_name}-uploads-{account_id}`，以確保全域唯一。
