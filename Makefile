s3_bucket="${PROJECT}-tf"
key="terraform-skeleton"
dynamodb_table="terraform-${PROJECT}-lock"
region=${AWS_REGION}

.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

stateinit: ## Initializes the bucket and dynamodb for state
	@if [ -z $(PROJECT) ]; then echo "PROJECT was not set" ; exit 10 ; fi
	@terraform init

stateplan: stateinit ## Shows the plan
	@terraform plan -input=false -refresh=true -var 'tf_project=${PROJECT}'

stateapply: stateinit
	@terraform apply -input=true -refresh=true -var 'tf_project=${PROJECT}'

init: ## Initializes the terraform remote state backend and pulls the correct projects state.
	@if [ -z $(PROJECT) ]; then echo "PROJECT was not set" ; exit 10 ; fi
	@rm -rf .terraform/*.tf*
	@terraform init \
        -backend-config="bucket=${s3_bucket}" \
        -backend-config="key=${key}.tfstate" \
        -backend-config="dynamodb_table=${dynamodb_table}" \
        -backend-config="region=${region}"

update: ## Gets any module updates
	@terraform get -update=true &>/dev/null

plan: init update ## Runs a plan. Note that in Terraform < 0.7.0 this can create state entries.
	@terraform plan -input=false -refresh=true -var-file=projects/$(PROJECT)/inputs.tfvars

plan-destroy: init update ## Shows what a destroy would do.
	@terraform plan -input=false -refresh=true -module-depth=-1 -destroy -var-file=projects/$(PROJECT)/inputs.tfvars

show: init ## Shows a module
	@terraform show -module-depth=-1

graph: ## Runs the terraform grapher
	@rm -f graph.png
	@terraform graph -draw-cycles -module-depth=-1 | dot -Tpng > graph.png
	@open graph.png

apply: init update ## Applies a new state.
	@terraform apply -input=true -refresh=true -var-file=projects/$(PROJECT)/inputs.tfvars

output: update ## Show outputs of a module or the entire state.
	@if [ -z $(MODULE) ]; then terraform output ; else terraform output -module=$(MODULE) ; fi

destroy: init update ## Destroys targets
	@terraform destroy -var-file=projects/$(PROJECT)/inputs.tfvars
