
// https://developer.hashicorp.com/terraform/language/terraform
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" // Allow minor version and patch updates
    }

  }

}

// https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  region = var.region
}

