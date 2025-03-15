// Partial configuration for the S3 backend
// https://developer.hashicorp.com/terraform/language/backend#partial-configuration
//
// terraform -chdir=./stacks/<stack_name>/ init -backend-config="./backends/<env>.config" -reconfigure
terraform {
  backend "s3" {
    bucket         = ""
    key            = ""
    region         = ""
    dynamodb_table = ""
    encrypt        = true
  }
}