# Archive lambda function first
cd functions/viewer-request && zip -r ../../modules/public_asset_hosting_cloudfront_edge_lambda/functions/viewer-request/auth.zip auth.py && cd ../../

export NZ_STACK_NAME="public_asset_hosting_lambdaedge"
uv run scripts/tf-stack.py init $NZ_STACK_NAME dev

uv run scripts/tf-stack.py apply $NZ_STACK_NAME dev

outputs=$(uv run scripts/tf-stack.py output $NZ_STACK_NAME dev)  
export NZ_BUCKET=$(echo $outputs | jq -r '.public_assets_bucket.value')
export NZ_WEBSITE=$(echo $outputs | jq -r '.public_assets_url.value')
env | grep NZ

aws s3 cp static_assets/ "s3://${NZ_BUCKET}/" --recursive