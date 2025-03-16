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