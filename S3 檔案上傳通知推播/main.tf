terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 打包 Lambda 程式碼
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda 執行角色
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-s3-notify-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda 基本執行權限（寫 CloudWatch Logs）
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 讀取事件權限（由 S3 觸發 Lambda 時需要）
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.uploads.arn}/*"
      }
    ]
  })
}

# Lambda 函式
resource "aws_lambda_function" "s3_notify" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-s3-upload-notify"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

# S3 Bucket（圖片上傳用）
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-uploads"
  }
}

# 允許 Lambda 被 S3 呼叫
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_notify.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

# 取得目前 AWS 帳號 ID
data "aws_caller_identity" "current" {}

# S3 事件通知：物件建立時觸發 Lambda（僅限圖片副檔名）
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notify.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notify.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpeg"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notify.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notify.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".gif"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_notify.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".webp"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
