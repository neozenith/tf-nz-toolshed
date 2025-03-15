# public_asset_hosting

## Quickstart

```sh
terraform -chdir=stacks/public_asset_hosting/ init -backend-config=./backends/<env>.config -reconfigure
terraform -chdir=stacks/public_asset_hosting/ plan -var environment=<env>
terraform -chdir=stacks/public_asset_hosting/ apply -var environment=<env>
```

or

```sh
uv run scripts/tf-stack.py init public_asset_hosting <env>
uv run scripts/tf-stack.py plan public_asset_hosting <env>
uv run scripts/tf-stack.py apply public_asset_hosting <env>
```