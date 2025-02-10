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
	@cd hummingbird/terraform && tflocal init && tflocal apply -auto-approve -var-file='.local.tfvars'

plan-tf-local:
	@cd hummingbird/terraform-state && tflocal init && tflocal apply -auto-approve
	@cd hummingbird/terraform && tflocal init && tflocal plan -var-file='.local.tfvars'

deploy-tf-prd:
	@cd hummingbird/terraform-state && terraform init && terraform apply -auto-approve
	@cd hummingbird/terraform && terraform init && terraform apply -auto-approve -var-file='.prd.tfvars'

plan-tf-prod:
	@cd hummingbird/terraform-state && terraform init && terraform apply -auto-approve
	@cd hummingbird/terraform && terraform init && terraform plan -var-file='.prd.tfvars'

run-all:
	@make start
	@make deploy-tf-local

redeploy-image:
	@cd hummingbird/terraform && tflocal apply -target=module.ecr -auto-approve

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

.PHONY: start stop localstack-logs clean-terraform-state \
				deploy-tf-local plan-tf-local run-all redeploy-image \
				list-ecs-services list-ecs-tasks
