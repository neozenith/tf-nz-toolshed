// Input Variables
// https://developer.hashicorp.com/terraform/language/values/variables#using-input-variable-values
//
// There are many ways to inject input variables to parameterise infrastructure definitions. Please read the terraform docs and understand them.
// In short, you can pass variables in the following ways:
//
// Individual Flags: 
//    terraform apply -var="region=us-east-1"
// TFVars files:
//    terraform apply -var-file="dev.tfvars"
// Environment Variables:
//    export TF_VAR_region=us-east-1
//    terraform apply

variable "region" {
  description = "The AWS region"
  default     = "ap-southeast-2"
  type        = string
  nullable    = false
}

variable "project_name" {
  description = "The project name"
  default     = "tf-nz-toolshed"
  type        = string
  nullable    = false
}

variable "repo_url" {
  description = "The repository URL managing this terraform stack"
  default     = "https://github.com/neozenith/tf-nz-toolshed/"
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