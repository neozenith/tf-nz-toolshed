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
	