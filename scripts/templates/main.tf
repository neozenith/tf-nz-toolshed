terraform {
  required_version = ">= 1.10.0"
}

locals {
  default_tags = { #tflint-ignore: terraform_unused_declarations
    Environment = var.environment
    Project     = var.project_name
    Repo        = var.repo_url
  }
}