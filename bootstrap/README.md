# Bootstrap Instructions & CF Templates

<!--TOC-->

- [Bootstrap Instructions & CF Templates](#bootstrap-instructions--cf-templates)
  - [\[Github Actions OIDC Provider & Role\](./github-actions.yaml)](#github-actions-oidc-provider--rolegithub-actionsyaml)
  - [\[Terraform S3 Backend\](./terraform-backend.yaml)](#terraform-s3-backendterraform-backendyaml)
- [Quickstart](#quickstart)
- [Github Actions](#github-actions)

<!--TOC-->

## [Github Actions OIDC Provider & Role](./github-actions.yaml)

CF template to create Github OIDC Provider and Role for Github Actions. CF template based from [Github example](https://github.com/aws-actions/configure-aws-credentials/tree/main/examples/federated-setup). See documentation on [Github](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) and [AWS](https://aws.amazon.com/blogs/security/use-iam-roles-to-connect-github-actions-to-actions-in-aws/) for more details.

## [Terraform S3 Backend](./terraform-backend.yaml)

CF template to create Terraform S3 Backend bucket and DynamoDB lock table, see [terraform documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3) for more info.


# Quickstart

- Open up the AWS Console 
- Head to Cloudformation
- Create New Stack
- Upload Template
- For the Github OIDC, leave the OIDCProviderARN empty `""` so that it will create one. 
    - Fill it in if there is already an OIDCProvider but you want to link a new role for a new repo to the exiting OIDC Provider.
- For the Terraform Backend, specify a `name` and `bucket name`
- Check the Outputs tab of each stack created.

# Github Actions

- Under the `github/workflows` folder you can find some example workflows to help bootstrap CI/CD processes.
- Move these file to your `.github/workflows` folder in the root of your repo.
- You will need to configure the Repository Secrets for `TERRAFORM_AWS_ROLE_ARN_<ENV>` at: https://github.com/yourorgname/yourreponame/settings/secrets/actions

