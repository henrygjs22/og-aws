output "s3_bucket_name" {
  description = "圖片上傳用 S3 Bucket 名稱"
  value       = aws_s3_bucket.uploads.id
}

output "s3_bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.uploads.arn
}

output "lambda_function_name" {
  description = "S3 上傳通知 Lambda 函式名稱"
  value       = aws_lambda_function.s3_notify.function_name
}

output "upload_command" {
  description = "上傳測試圖片範例（請先安裝 AWS CLI 並設定認證）"
  value       = "aws s3 cp <本地圖片路徑> s3://${aws_s3_bucket.uploads.id}/"
}
