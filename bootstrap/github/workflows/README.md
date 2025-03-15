# Terraform Github Actions Workflows

<!--TOC-->

- [Terraform Github Actions Workflows](#terraform-github-actions-workflows)
  - [DEV](#dev)
  - [TEST](#test)
  - [PROD](#prod)

<!--TOC-->

## DEV

On push to (non-draft) PR deploy to DEV account.

## TEST

On PR merge to `main` OR manual trigger deploy of `main` with `test` as target, then deploy to TEST account.


## PROD

Prod requires a manual dispatch from `main` branch with environment target as `prod`.