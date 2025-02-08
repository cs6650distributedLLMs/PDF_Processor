start:
	@docker compose up -d

stop:
	@docker compose down

localstack-logs:
	@docker logs --follow localstack

deploy-tf-local:
	@cd hummingbird/terraform-state && tflocal init && tflocal apply --auto-approve
	@cd hummingbird/terraform && tflocal init && tflocal apply --auto-approve

plan-tf-local:
	@cd hummingbird/terraform-state && tflocal init && tflocal apply --auto-approve
	@cd hummingbird/terraform && tflocal init && tflocal plan

run-all:
	@make start
	@make deploy-tf-local

.PHONY: start stop logs deploy-tf-local plan-tf-local run-all
