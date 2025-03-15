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

# use the module public_asset_hosting_public_s3

module "public_asset_hosting_cloudfront_edge_lambda" {
  source       = "../../modules/public_asset_hosting_cloudfront_edge_lambda"
  project_name = var.project_name
  repo_url     = var.repo_url
  environment  = var.environment
}

#outputs for the module
output "public_assets_bucket" {
  value = module.public_asset_hosting_cloudfront_edge_lambda.bucket_name
}

output "public_assets_url" {
  value = "http://${module.public_asset_hosting_cloudfront_edge_lambda.cloudfront_domain_name}"
}

output "curl_command" {
  value = "curl -H \"x-custom-auth: your-secret-value\" -I http://${module.public_asset_hosting_cloudfront_edge_lambda.cloudfront_domain_name}/index.html"
}
