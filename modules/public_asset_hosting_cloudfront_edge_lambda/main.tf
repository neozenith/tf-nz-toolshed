terraform {
  required_version = ">= 1.10.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project_name" {
  description = "The project name"
  default     = "tf-nz-toolshed"
  type        = string
  nullable    = false
}

variable "repo_url" {
  description = "The repository URL managing this terraform stack"
  default     = ""
  type        = string
  nullable    = false
}

variable "environment" {
  //Eg: export TF_VAR_environment=dev
  description = "Deployment Environment AWS Account. dev/test/prod"
  type        = string
  nullable    = false
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "The environment must be one of 'dev', 'test', 'prod'."
  }
}


locals {
  default_tags = { #tflint-ignore: terraform_unused_declarations
    Environment = var.environment
    Project     = var.project_name
    Repo        = var.repo_url
  }
}
resource "aws_s3_bucket" "public_assets" {
  bucket = "${var.project_name}-${var.environment}-public-assets-cf-oac-lambda-edge"
  tags   = local.default_tags
}

resource "aws_s3_bucket_public_access_block" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "public_assets" {
  depends_on = [
    aws_s3_bucket_public_access_block.public_assets,
    aws_s3_bucket_ownership_controls.public_assets,
  ]

  bucket = aws_s3_bucket.public_assets.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Add website configuration
resource "aws_s3_bucket_website_configuration" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
resource "aws_s3_bucket_policy" "public_assets" {
  depends_on = [aws_s3_bucket_public_access_block.public_assets]
  bucket     = aws_s3_bucket.public_assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.public_assets.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "lambda_edge" {
  name = "${var.project_name}-${var.environment}-lambda-edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_edge" {
  name = "${var.project_name}-${var.environment}-lambda-edge"
  role = aws_iam_role.lambda_edge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_lambda_function" "auth_check" {
  provider         = aws.us_east_1  # Lambda@Edge must be in us-east-1
  filename         = "${path.module}/functions/viewer-request/auth.zip"
  function_name    = "${var.project_name}-${var.environment}-auth-check"
  role            = aws_iam_role.lambda_edge.arn
  handler         = "auth.lambda_handler"
  runtime         = "python3.12"
  publish         = true  # Required for Lambda@Edge

  tags = local.default_tags
}


resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-${var.environment}-oac-lmbdaedge"
  description                       = "Origin Access Controls for static website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled             = true
  is_ipv6_enabled    = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  tags                = local.default_tags

  origin {
    domain_name              = aws_s3_bucket.public_assets.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
    origin_id                = "S3Origin"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    compress              = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.auth_check.qualified_arn
      include_body = false
    }
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Define module outputs
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}

output "bucket_name" {
  value = aws_s3_bucket.public_assets.bucket
}


output "lambda_function_name" {
  value = aws_lambda_function.auth_check.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.auth_check.qualified_arn
}