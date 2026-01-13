SHELL         := /bin/bash
TERRAFORM     := $(shell which tofu)
S3_REGION     := $(shell sops decrypt secrets/secrets.yaml | grep ^s3_region     | cut -d ' ' -f 2)
S3_BUCKET     := $(shell sops decrypt secrets/secrets.yaml | grep ^s3_bucket     | cut -d ' ' -f 2)
S3_KEY        := $(shell sops decrypt secrets/secrets.yaml | grep ^s3_key        | cut -d ' ' -f 2)
S3_ACCESS_KEY := $(shell sops decrypt secrets/secrets.yaml | grep ^s3_access_key | cut -d ' ' -f 2)
S3_SECRET_KEY := $(shell sops decrypt secrets/secrets.yaml | grep ^s3_secret_key | cut -d ' ' -f 2)

.PHONY: help init plan apply migrate test pre-commit-check-deps pre-commit-install-hooks clean

help:
	@echo "General targets"
	@echo "----------------"
	@echo
	@echo "\thelp: show this help text"
	@echo "\tclean: removes all .terraform directories"
	@echo
	@echo "Terraform targets"
	@echo "-----------------"
	@echo
	@echo "\tinit: run 'terraform init'"
	@echo "\ttest: fetch canonical pre-commit config and run checks"
	@echo "\tplan: run 'terraform plan'"
	@echo "\tapply: run 'terraform apply'"
	@echo "\tmigrate; run terraform init -migrate-state"
	@echo
	@echo "One-time repo init targets"
	@echo "--------------------------"
	@echo
	@echo "\tpre-commit-install-hooks: install pre-commit hooks"
	@echo "\tpre-commit-check-deps: check pre-commit dependencies"
	@echo

clean:
	@find . -name .terraform -type d | xargs -I {} rm -rf {}

init: clean .terraform/terraform.tfstate

.terraform/terraform.tfstate:
	@${TERRAFORM} init -reconfigure -upgrade -input=false -backend-config="key=${S3_KEY}" -backend-config="bucket=${S3_BUCKET}" -backend-config="region=${S3_REGION}" -backend-config="access_key=${S3_ACCESS_KEY}" -backend-config="secret_key=${S3_SECRET_KEY}"

plan: init .terraform/plan

.terraform/plan:
	@${TERRAFORM} plan -compact-warnings -no-color -out /tmp/tfplan.bin
	@${TERRAFORM} show -no-color /tmp/tfplan.bin | tee plan-output.txt
	@rm -f /tmp/tfplan.bin

apply: init .terraform/apply

.terraform/apply:
	@${TERRAFORM} apply -auto-approve -compact-warnings

migrate:
	@echo "First use -make init- using the old S3 backend, then run -make migrate- to use the new one."
	@${TERRAFORM} init -migrate-state -backend-config="key=${S3_KEY}" -backend-config="bucket=${S3_BUCKET}" -backend-config="region=${S3_REGION}" -backend-config="access_key=${S3_ACCESS_KEY}" -backend-config="secret_key=${S3_SECRET_KEY}"

test: .pre-commit-config.yaml .git/hooks/pre-commit
	@pre-commit run -a

.pre-commit-config.yaml:
	@curl -sSL -o .pre-commit-config.yaml \
		https://raw.githubusercontent.com/makeitworkcloud/images/main/tfroot-runner/pre-commit-config.yaml

DEPS_PRE_COMMIT=$(shell which pre-commit || echo "pre-commit not found")
DEPS_TERRAFORM_DOCS=$(shell which terraform-docs || echo "terraform-docs not found")
DEPS_TFLINT=$(shell which tflint || echo "tflint not found,")
DEPS_CHECKOV=$(shell which checkov || echo "checkov not found,")
DEPS_JQ=$(shell which jq || echo "jq not found,")
pre-commit-check-deps:
	@echo "Checking for pre-commit and its dependencies:"
	@echo "  pre-commit: ${DEPS_PRE_COMMIT}"
	@echo "  terraform-docs: ${DEPS_TERRAFORM_DOCS}"
	@echo "  tflint: ${DEPS_TFLINT}"
	@echo "  checkov: ${DEPS_CHECKOV}"
	@echo "  jq: ${DEPS_JQ}"
	@echo ""

pre-commit-install-hooks: .git/hooks/pre-commit

.git/hooks/pre-commit: pre-commit-check-deps
	@pre-commit install --install-hooks
