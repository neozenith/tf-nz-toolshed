# ruff: noqa: E501
# /// script
# requires-python = ">=3.11"
# dependencies = [
# "jinja2",
# "ruamel.yaml",
# "types-jinja2",
# "boto3"
# ]
# ///
# https://docs.astral.sh/uv/guides/scripts/#creating-a-python-script
# https://packaging.python.org/en/latest/specifications/inline-script-metadata/#inline-script-metadata

import sys
import shlex
from pathlib import Path
import shutil
import logging
import subprocess
from typing import Any

import boto3
import ruamel.yaml
import jinja2

log = logging.getLogger(__name__)

log_level = logging.DEBUG if "--debug" in sys.argv else logging.INFO
log_format = "%(asctime)s::%(name)s::%(levelname)s::%(module)s:%(funcName)s:%(lineno)d| %(message)s" if "--debug" in sys.argv else "%(message)s"
log_date_format = "%Y-%m-%d %H:%M:%S"
if "--debug" in sys.argv:
    sys.argv.remove("--debug") # Safe to remove as we have handled it

logging.basicConfig(level=log_level, format=log_format, datefmt=log_date_format)
PROJECT_NAME = "tf-nz-toolshed"
VALID_ACCOUNTS = {
    "389956346255": "dev",
    "675457518233": "test",
    "999610420645": "prod"
}

VALID_ENVS = ["dev", "test", "prod"]
VALID_COMMANDS = ["validate", "create", "gha-check", "init", "plan", "apply", "destroy", "output"]

class TerraformBackendConfigError(Exception):
    ...

class TFStackCLIInputError(Exception):
    ...

class TFStackAWSConfigurationError(Exception):
    ...

class TFStackCouldNotFindGitRepoRoot(Exception):
    ...

def find_backend_config(working_dir: Path = Path.cwd()) -> list[Path]:
    stack_configs = (working_dir / "stacks").glob("**/backends/*.config")
    return list(stack_configs)

def get_caller_identity():
    sts = boto3.client('sts')
    try:
        return sts.get_caller_identity()
    except Exception as e:
        log.error(f"Failed to get caller identity: {e}")
        raise

def check_account(environment: str):
    output = get_caller_identity()
    account_id = output["Account"]
    if account_id not in VALID_ACCOUNTS:
        raise TFStackAWSConfigurationError(f"Invalid account: {account_id}")
        
    if VALID_ACCOUNTS[account_id] != environment:
        raise TFStackAWSConfigurationError(f"Invalid environment for aws account {account_id}. Must be '{VALID_ACCOUNTS[account_id]}' for the current aws credentials.")
        
    log.debug(f"Running in account {account_id} for environment {environment}")


########################################################################################
# Standalone .env style key = value config file parser
########################################################################################

def __parse_env_line(line: str) -> tuple[str | None, str | None]:
    """Parses a single line into a key-value pair. Handles quoted values and inline comments.
    Returns (None, None) for invalid lines."""
    # Guard checks for empty lines or lines without '='
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        return None, None

    # Split the line into key and value at the first '='
    key, value = line.split("=", 1)
    key = key.strip()

    # Use shlex to process the value (handles quotes and comments)
    lexer = shlex.shlex(value, posix=True)
    lexer.whitespace_split = True  # Tokenize by whitespace
    value = "".join(lexer)  # Preserve the full quoted/cleaned value

    return key, value


def read_config_file(file_path: str) -> dict[str, str] | None:
    """Reads a config file file and returns a dictionary of key-value pairs.
    If the file does not exist or is not a regular file, returns None.
    """
    file = Path(file_path)
    return (
        {
            key: value
            for key, value in map(__parse_env_line, file.read_text().splitlines())
            if key is not None and value is not None
        }
        if file.is_file()
        else None
    )

def find_git_root(path: Path) -> Path | None:
    """
    Find the root directory of the git repository containing the given path.
    Returns None if the path is not in a git repository.
    """
    try:
        import subprocess
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            cwd=path,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        return None

########################################################################################
# Core CLI Commands
########################################################################################

def validate(project: str, working_dir: Path = Path.cwd()):
    config_paths = find_backend_config(working_dir=working_dir)
    parsed_configs = {str(path):read_config_file(str(path)) for path in config_paths}

    results: dict[str, list[Any]] = {}

    for k, v in parsed_configs.items():
        config_path = Path(k)
        results[k] = []
        env_config = config_path.stem
        if env_config not in VALID_ENVS:
            results[k].append(TerraformBackendConfigError(f"Invalid environment: {env_config}, must be one of {VALID_ENVS}"))
        
        stack_name = config_path.parts[config_path.parts.index("stacks") + 1]    
        if v and "key" in v:
            tf_state_key = Path(v["key"])
            expected_key = f"{project}/{env_config}/{stack_name}/terraform.tfstate"
            if str(tf_state_key) != expected_key:
                results[k].append(TerraformBackendConfigError(f"Invalid 'key' in {k}: {tf_state_key}, must be '{expected_key}'"))
        else:
            results[k].append(TerraformBackendConfigError(f"'key' not found in {config_path}"))

        if len(results[k]) == 0:
            log.info(f"✅ {k} is valid")
        else:
            log.error(f"❌ {k} is invalid {results[k]}")
    total_errors = sum([len(v) for v in results.values()])
    log.info(f"Errors: {total_errors}")
    if total_errors > 0:
        sys.exit(1)

def create(stack_name: str, project:str, working_dir: Path = Path.cwd()):
    yaml = ruamel.yaml.YAML()
    templates_path = working_dir / "scripts" / "templates"
    backend_config_template = templates_path / "backends" / "base.config.j2"
    readme_template = templates_path / "README.md.j2"
    
    stacks_path = working_dir / "stacks"
    target_stack_path = stacks_path / stack_name
    target_stack_backends_path = target_stack_path / "backends"
    base_config_path = working_dir / "config.yml"
    base_config = yaml.load(base_config_path.read_text())

    if target_stack_path.exists():
        log.info(f"Stack {stack_name} already exists")
        sys.exit(0)

    # Make folder structure
    log.info(f"Creating stack: {stack_name}")
    log.info(f"Creating folder structure in: {target_stack_path.relative_to(working_dir)}")
    target_stack_path.mkdir(parents=True)
    target_stack_backends_path.mkdir(parents=True)

    # Copy terraform files
    log.debug(f"Saearching {templates_path.relative_to(working_dir)} for terraform files")
    tf_files = list(templates_path.glob("*.tf"))
    log.debug(f"Found {len(tf_files)} terraform files {tf_files}")
    for tf_file in tf_files:
        target_tf_file = target_stack_path / tf_file.name
        log.info(f"    Copying {tf_file.relative_to(working_dir)} --> {target_tf_file.relative_to(working_dir)}")
        shutil.copy2(tf_file, target_tf_file)

    # Templating Backend Config
    log.info(f"Creating backend config for: {stack_name}")
    log.info(f"Reading base config from {base_config_path.relative_to(working_dir)}")
    log.debug(f"Base config: {base_config}")
    for environment, env_config in base_config["environments"].items():
        log.info(f"    Creating backend config for: {environment}")
        env_config_path = target_stack_backends_path / f"{environment}.config"
        env_config["environment"] = environment 
        env_config["stack_name"] = stack_name
        env_config["project"] = project

        templated_config = jinja2.Template(backend_config_template.read_text(), undefined=jinja2.StrictUndefined).render(**env_config)

        log.debug(f"Templated config: {templated_config}")
        log.info(f"    Writing backend config to {env_config_path.relative_to(working_dir)}")
        env_config_path.write_text(templated_config)

    # Template README.md
    log.info(f"Creating README.md for: {stack_name}")
    readme_path = target_stack_path / "README.md"
    templated_config = jinja2.Template(readme_template.read_text(), undefined=jinja2.StrictUndefined).render(stack_name=stack_name)
    readme_path.write_text(templated_config)
    log.info(f"Stack {stack_name} created successfully ✅")
    
    
def update_github_actions(fix: bool = False, working_dir: Path = Path.cwd()):
    git_root = find_git_root(working_dir)
    if not git_root:
        raise TFStackCouldNotFindGitRepoRoot(f"Could not find git repository root from {working_dir}")
    
    gha_path = git_root / ".github" / "workflows" / "terraform-cicd-parent.yml"
    yaml = ruamel.yaml.YAML()
    yaml.preserve_quotes = True
    yaml.sort_keys = False
    yaml.indent(mapping=2, sequence=4, offset=2)
    gha = yaml.load(gha_path.read_text(encoding="utf-8"))
    log.debug(f"Current GHA: {gha}")
    gha_stack_list = gha["jobs"]["tf-per-stack"]["strategy"]["matrix"]["stack"]
    log.info(f"Current GHA: {gha_stack_list}")
    
    stacks_path = working_dir / "stacks"
    stacks = [stack.name for stack in stacks_path.iterdir() if stack.is_dir()]
    log.info(f"Found stacks: {stacks}")
    # Find differences between lists
    stacks_set = set(stacks)
    gha_set = set(gha_stack_list)

    added = stacks_set - gha_set
    removed = gha_set - stacks_set

    if added or removed:
        log.info(f"Added stacks: {added}")
        log.info(f"Removed stacks: {removed}")

        if fix:
            log.info("Fixing GHA")
            gha["jobs"]["tf-per-stack"]["strategy"]["matrix"]["stack"] = stacks
            yaml.dump(gha, gha_path)
            log.info("GHA fixed ✅")
        else:
            log.info("GHA not fixed. Use --fix to update GHA with the new stacks")
            sys.exit(1)

    else:
        log.info("No changes required. GHA is up to date. ✅")
        sys.exit(0)

def stacks(working_dir: Path = Path.cwd()) -> list[str]:
    stacks_path = working_dir / "stacks"
    stacks = [stack.name for stack in stacks_path.iterdir() if stack.is_dir()]
    return stacks

def tf(command: str, stack_name: str, environment: str, working_dir: Path = Path.cwd()):
    stack_path = working_dir / "stacks" / stack_name
    env_tfvars = stack_path / f"{environment}.tfvars"
    env_tfvars_flag = f"-var-file={env_tfvars.relative_to(stack_path)}" if env_tfvars.exists() else ""
    if not stack_path.exists():
        log.error(f"Stack {stack_name} does not exist")
        sys.exit(1)
    
    if command == "init":
        tf_command = f"terraform -chdir={stack_path.relative_to(working_dir)} init -backend-config=./backends/{environment}.config -reconfigure"
    elif command == "plan":
        tf_command = f"terraform -chdir={stack_path.relative_to(working_dir)} plan -no-color -input=false -var environment={environment} {env_tfvars_flag}"
    elif command == "apply":
        tf_command = f"terraform -chdir={stack_path.relative_to(working_dir)} apply -no-color -input=false -var environment={environment} {env_tfvars_flag} -auto-approve"
    elif command == "destroy":
        tf_command = f"terraform -chdir={stack_path.relative_to(working_dir)} destroy -no-color -input=false -var environment={environment} {env_tfvars_flag} -auto-approve"
    elif command == "output":
        tf_command = f"terraform -chdir={stack_path.relative_to(working_dir)} output -json"

    log.info(f"Running\n\n{tf_command}\n\nin directory: {stack_path.relative_to(working_dir)}")
    return subprocess.run(shlex.split(tf_command), text=True, cwd=working_dir, check=True)

    
########################################################################################
# Entrypoint
########################################################################################
def main(working_dir: Path = Path.cwd()):

    if len(sys.argv) <= 1:
        raise TFStackCLIInputError(f"No valid command provided. Must be one of {VALID_COMMANDS}")
    
    if sys.argv[1] not in VALID_COMMANDS:
        raise TFStackCLIInputError(f"The argument {sys.argv[1]} is not a valid command. Must be one of {VALID_COMMANDS}")
    
    command = sys.argv[1]
    if command == "validate":
        validate(project=PROJECT_NAME, working_dir=working_dir)

    elif command == "create":
        if len(sys.argv) <= 2:
            raise TFStackCLIInputError("No stack name provided")

        create(stack_name=sys.argv[2], project=PROJECT_NAME, working_dir=working_dir)

    elif command == "gha-check":
        should_fix = (len(sys.argv) >=3 and "--fix" == sys.argv[2])
        update_github_actions(fix=should_fix, working_dir=working_dir)

    elif command in ["init", "plan", "apply", "destroy", "output"]:
        valid_stacks = stacks(working_dir=working_dir)
        if len(sys.argv) <= 2:
            raise TFStackCLIInputError(f"No stack name provided. Must be one of {valid_stacks}")

        stack_name = sys.argv[2]
        if stack_name not in valid_stacks:
            raise TFStackCLIInputError(f"Stack {stack_name} does not exist. Must be one of {valid_stacks}")

        if len(sys.argv) <= 3:
            raise TFStackCLIInputError(f"No environment name provided. Must be one of {VALID_ENVS}")
        
        environment = sys.argv[3]

        output = get_caller_identity()
        for k in ['Account', 'UserId', 'Arn']:
            log.info(f"{k}: {output[k]}")
        
        check_account(environment)

        result = tf(command, stack_name, environment, working_dir=working_dir)
        log.info(result)
        
        
if __name__ == "__main__":
    # Setting up working directory as a parameter incase there are issues later about the relative paths
    working_dir = Path.cwd()

    try:
        main(working_dir=working_dir)
    except Exception as e:
        log.error(f"❌ {e}")
        sys.exit(1)