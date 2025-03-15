# Ensure the .make folder exists when starting make
# We need this for build targets that have multiple or no file output.
# We 'touch' files in here to mark the last time the specific job completed.
_ := $(shell mkdir -p .make)
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: clean init plan apply deploy

################################# MISC #################################

init: .venv/deps pyproject.toml
# Ensure the virtual environment has the correct basic tooling before we get to the pyproject.toml
.venv/bin/python3:
	[ ! -d ".venv" ] && python3 -m venv .venv || echo ".venv already setup"
	# .venv/bin/python3 -m pip install -qq --upgrade pip uv pre-commit
	# .venv/bin/pre-commit install
	
.venv/deps: .venv/bin/python3 pyproject.toml # Manage script dependencies
	uv sync
	touch $@

login:
	export AWS_PROFILE=389956346255_play_dev_tf
	export AWS_ROLE="arn:aws:iam::389956346255:role/github-actions-oidc-389956346255-Role-bsUeew80Yg0G"
	# aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text
	eval "$(aws configure export-credentials --format env --profile $AWS_PROFILE)"
	creds=$(aws sts assume-role \
		--role-arn "${AWS_ROLE}" \
		--role-session-name "TerraformCLIUsage" \
		--duration-seconds 3600 \
		--profile $AWS_PROFILE)
	export AWS_ACCESS_KEY_ID=$(echo $creds | jq -r '.Credentials.AccessKeyId')
	export AWS_SECRET_ACCESS_KEY=$(echo $creds | jq -r '.Credentials.SecretAccessKey')
	export AWS_SESSION_TOKEN=$(echo $creds | jq -r '.Credentials.SessionToken')
	export AWS_CREDENTIAL_EXPIRATION=$(echo $creds | jq -r '.Credentials.Expiration')
	env | grep AWS

basic:

	export NZ_STACK_NAME="public_asset_hosting"
	uv run scripts/tf-stack.py init $NZ_STACK_NAME dev
	uv run scripts/tf-stack.py apply $NZ_STACK_NAME dev
	outputs=$(uv run scripts/tf-stack.py output $NZ_STACK_NAME dev)  
	export NZ_BUCKET=$(echo $outputs | jq -r '.public_assets_bucket.value')
	export NZ_WEBSITE=$(echo $outputs | jq -r '.public_assets_url.value')
	env | grep NZ
	aws s3 cp static_assets/ "s3://${NZ_BUCKET}/" --recursive

https:
	export NZ_STACK_NAME="public_asset_hosting_https"
	uv run scripts/tf-stack.py init $NZ_STACK_NAME dev
	uv run scripts/tf-stack.py apply $NZ_STACK_NAME dev
	outputs=$(uv run scripts/tf-stack.py output $NZ_STACK_NAME dev)  
	export NZ_BUCKET=$(echo $outputs | jq -r '.public_assets_bucket.value')
	export NZ_WEBSITE=$(echo $outputs | jq -r '.public_assets_url.value')
	env | grep NZ
	aws s3 cp static_assets/ "s3://${NZ_BUCKET}/" --recursive

lambda_edge:
	export NZ_STACK_NAME="public_asset_hosting_lambdaedge"
	uv run scripts/tf-stack.py init $NZ_STACK_NAME dev
	
	cd functions/viewer-request && zip -r ../../modules/public_asset_hosting_cloudfront_edge_lambda/functions/viewer-request/auth.zip auth.py && cd ../../
    
	uv run scripts/tf-stack.py apply $NZ_STACK_NAME dev
	outputs=$(uv run scripts/tf-stack.py output $NZ_STACK_NAME dev)  
	export NZ_BUCKET=$(echo $outputs | jq -r '.public_assets_bucket.value')
	export NZ_WEBSITE=$(echo $outputs | jq -r '.public_assets_url.value')
	env | grep NZ
	
	
	aws s3 cp static_assets/ "s3://${NZ_BUCKET}/" --recursive
	

clean: # Clean derived artifacts as though a clean checkout.
	rm -rfv **/.terraform
	rm -rfv **/.terraform.lock.hcl
	rm -rfv .make
	rm -rfv .venv


lint: # Perform quality control checks
	terraform fmt -recursive -list=true
	uv run scripts/tf-stack.py validate
	tflint --recursive -f compact
	

format: # Format the code
	terraform fmt -recursive -list=true

docs: # Generate documentation
	uv run md_toc --in-place github --header-levels 2 README.md **/*.md
	terraform-docs markdown table --output-file README.md --output-mode inject modules/*
	