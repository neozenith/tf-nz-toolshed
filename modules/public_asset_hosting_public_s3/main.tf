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
  bucket = "${var.project_name}-${var.environment}-public-assets"
  tags   = local.default_tags
}

resource "aws_s3_bucket_public_access_block" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
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
  acl    = "public-read"
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
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.public_assets.arn}/*"
      },
    ]
  })
}


# Add CORS configuration if needed
resource "aws_s3_bucket_cors_configuration" "public_assets" {
  bucket = aws_s3_bucket.public_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Define module outputs
output "bucket_name" {
  value = aws_s3_bucket.public_assets.bucket
}


output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.public_assets.website_endpoint
}

output "website_domain" {
  value = aws_s3_bucket_website_configuration.public_assets.website_domain
}