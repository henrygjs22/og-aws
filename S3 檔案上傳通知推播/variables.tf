variable "aws_region" {
  description = "AWS 部署區域"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "專案名稱，用於資源命名"
  type        = string
  default     = "s3-upload-notify"
}

variable "discord_webhook_url" {
  description = "Discord Webhook URL，用於上傳通知推播"
  type        = string
  sensitive   = true
}
