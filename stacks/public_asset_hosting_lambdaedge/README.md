# public_asset_hosting_lambdaedge

## Quickstart

```sh
terraform -chdir=stacks/public_asset_hosting_lambdaedge/ init -backend-config=./backends/<env>.config -reconfigure
terraform -chdir=stacks/public_asset_hosting_lambdaedge/ plan -var environment=<env>
terraform -chdir=stacks/public_asset_hosting_lambdaedge/ apply -var environment=<env>
```

or

```sh
uv run scripts/tf-stack.py init public_asset_hosting_lambdaedge <env>
uv run scripts/tf-stack.py plan public_asset_hosting_lambdaedge <env>
uv run scripts/tf-stack.py apply public_asset_hosting_lambdaedge <env>
```