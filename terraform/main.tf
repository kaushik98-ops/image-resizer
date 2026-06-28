terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "image-resizer"
}

variable "ecr_image_uri" {
  description = "ECR image URI from Jenkins. e.g. 123.dkr.ecr...:v1"
  type        = string
}

# S3 Buckets
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw-uploads-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "prod" {
  bucket = "${var.project_name}-resized-prod-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ECR Repo
resource "aws_ecr_repository" "lambda_repo" {
  name         = "${var.project_name}-lambda"
  force_delete = true
}

# IAM for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-lambda-s3-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.raw.arn}/*"
      },
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.prod.arn}/*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "resizer" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = var.ecr_image_uri
  timeout       = 30
  memory_size   = 1024

  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.prod.id
    }
  }
}

# S3 -> Lambda Trigger
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.resizer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }
  lambda_function {
    lambda_function_arn = aws_lambda_function.resizer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

# CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda errors"
  dimensions = {
    FunctionName = aws_lambda_function.resizer.function_name
  }
}

output "raw_bucket_name" {
  value = aws_s3_bucket.raw.id
}

output "prod_bucket_name" {
  value = aws_s3_bucket.prod.id
}

output "ecr_repo_url" {
  value = aws_ecr_repository.lambda_repo.repository_url
}
