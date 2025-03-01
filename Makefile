start:
	@docker compose up -d

stop:
	@docker compose down

localstack-logs:
	@docker logs --follow localstack

clean-terraform-state:
	@rm -rf terraform-state/.terraform terraform-state/.terraform.lock.hcl
	@rm -rf terraform-state/terraform.tfstate terraform-state/terraform.tfstate.backup
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl

deploy-tf-local:
	@cd terraform-state && tflocal init && tflocal apply -auto-approve
	@cd terraform && tflocal init && tflocal apply -auto-approve -var-file='.local.tfvars' -var-file='.secret.tfvars'

destroy-tf-local:
	@cd terraform && tflocal init && tflocal destroy -auto-approve -var-file='.local.tfvars' -var-file='.secret.tfvars'

plan-tf-local:
	@cd terraform-state && tflocal init && tflocal apply -auto-approve
	@cd terraform && tflocal init && tflocal plan -var-file='.local.tfvars' -var-file='.secret.tfvars'

deploy-tf-prd:
	@cd terraform-state && terraform init && terraform apply -auto-approve
	@cd terraform && terraform init && terraform apply -auto-approve -var-file='.prd.tfvars' -var-file='.secret.tfvars'

destroy-tf-prd:
	@cd terraform && terraform init && terraform destroy -auto-approve -var-file='.prd.tfvars' -var-file='.secret.tfvars'

plan-tf-prod:
	@cd terraform-state && terraform init && terraform apply -auto-approve
	@cd terraform && terraform init && terraform plan -var-file='.prd.tfvars' -var-file='.secret.tfvars'

run-all-local:
	@make clean-terraform-state
	@make start
	@make deploy-tf-local
	@make localstack-logs

redeploy-image:
	@cd terraform && tflocal apply -target=module.ecr -auto-approve

list-ecs-services:
	@awslocal ecs list-services --cluster hummingbird-ecs-cluster

list-ecs-tasks:
	@awslocal ecs list-tasks --cluster hummingbird-ecs-cluster

get-ecs-task-ips:
	@awslocal ecs list-tasks --cluster hummingbird-ecs-cluster --query 'taskArns' --output text | xargs -S1024 -I {} \
	 awslocal ecs describe-tasks --cluster hummingbird-ecs-cluster --tasks {} \
			--query 'tasks[*].attachments[*].details[?name==`privateIPv4Address`].value' --output text

get-alb-target-ips:
	@awslocal elbv2 describe-load-balancers --names hummingbird-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text | xargs -S1024 -I {} \
	 awslocal elbv2 describe-target-groups --load-balancer-arn {} --query 'TargetGroups[*].TargetGroupArn' --output text | xargs -S1024 -I {} \
	 awslocal elbv2 describe-target-health --target-group-arn {}

.PHONY: clean-terraform-state deploy-tf-local deploy-tf-prd \
				destroy-tf-local destroy-tf-local get-alb-target-ips \
				get-ecs-task-ips list-ecs-services list-ecs-tasks \
				localstack-logs plan-tf-local plan-tf-prod \
				redeploy-image run-all-local start stop
