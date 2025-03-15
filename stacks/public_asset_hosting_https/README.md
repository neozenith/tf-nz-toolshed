# public_asset_hosting_https

## Quickstart

```sh
terraform -chdir=stacks/public_asset_hosting_https/ init -backend-config=./backends/<env>.config -reconfigure
terraform -chdir=stacks/public_asset_hosting_https/ plan -var environment=<env>
terraform -chdir=stacks/public_asset_hosting_https/ apply -var environment=<env>
```

or

```sh
uv run scripts/tf-stack.py init public_asset_hosting_https <env>
uv run scripts/tf-stack.py plan public_asset_hosting_https <env>
uv run scripts/tf-stack.py apply public_asset_hosting_https <env>
```