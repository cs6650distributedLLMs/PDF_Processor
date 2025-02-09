start:
	@docker compose up -d

stop:
	@docker compose down

localstack-logs:
	@docker logs --follow localstack

clean-terraform-state:
	@rm -rf hummingbird/terraform-state/.terraform hummingbird/terraform-state/.terraform.lock.hcl
	@rm -rf hummingbird/terraform-state/terraform.tfstate hummingbird/terraform-state/terraform.tfstate.backup
	@rm -rf hummingbird/terraform/.terraform hummingbird/terraform/.terraform.lock.hcl

deploy-tf-local:
	@cd hummingbird/terraform-state && tflocal init && tflocal apply -auto-approve
	@cd hummingbird/terraform && tflocal init && tflocal apply -auto-approve

plan-tf-local:
	@cd hummingbird/terraform-state && tflocal init && tflocal apply -auto-approve
	@cd hummingbird/terraform && tflocal init && tflocal plan

run-all:
	@make start
	@make deploy-tf-local

redeploy-image:
	@cd hummingbird/terraform && tflocal apply -target=module.ecr -auto-approve

.PHONY: start stop localstack-logs clean-terraform-state deploy-tf-local plan-tf-local run-all redeploy-image
