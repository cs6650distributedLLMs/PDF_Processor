.PHONY: configure
configure:
	# Initialize Terraform workspaces
	@terraform workspace new hummingbird-aws
	@terraform workspace new hummingbird-local
	# Copy sample env files to permanent files
	@cp .env.sample .env
	@cp terraform/.secret.tfvars.sample terraform/.secret.tfvars
	# Install Lambda builder dependencies
	@cd hummingbird/lambdas && npm install

.PHONY: run-all-local
run-all-local:
	@make clean-terraform-state
	@make start
	@make deploy-tf-local
	@make localstack-logs

.PHONY: start
start:
	@docker compose up -d

.PHONY: stop
stop:
	@docker compose down

.PHONY: localstack-logs
localstack-logs:
	@docker logs --follow localstack

.PHONY: clean-terraform-state
clean-terraform-state:
	@rm -rf terraform-state/.terraform terraform-state/.terraform.lock.hcl
	@rm -rf terraform-state/terraform.tfstate terraform-state/terraform.tfstate.backup
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl

.PHONY: deploy-tf-local
deploy-tf-local:
	@terraform workspace select hummingbird-local
	@cd terraform-state && tflocal init && tflocal apply -auto-approve
	@cd terraform && tflocal init && tflocal apply -auto-approve -var-file='.local.tfvars' -var-file='.secret.tfvars'

.PHONY: destroy-tf-local
destroy-tf-local:
	@terraform workspace select hummingbird-local
	@cd terraform && tflocal init && tflocal destroy -auto-approve -var-file='.local.tfvars' -var-file='.secret.tfvars'

.PHONY: plan-tf-local
plan-tf-local:
	@terraform workspace select hummingbird-local
	@cd terraform-state && tflocal init && tflocal apply -auto-approve
	@cd terraform && tflocal init && tflocal plan -var-file='.local.tfvars' -var-file='.secret.tfvars'

.PHONY: deploy-tf-prd
deploy-tf-prd:
	@terraform workspace select hummingbird-aws
	@cd terraform-state && terraform init && terraform apply -auto-approve
	@cd terraform && terraform init && terraform apply -auto-approve -var-file='.prd.tfvars' -var-file='.secret.tfvars'

.PHONY: destroy-tf-prd
destroy-tf-prd:
	@terraform workspace select hummingbird-aws
	@cd terraform && terraform init && terraform destroy -auto-approve -var-file='.prd.tfvars' -var-file='.secret.tfvars'

.PHONY: plan-tf-prod
plan-tf-prod:
	@terraform workspace select hummingbird-aws
	@cd terraform-state && terraform init && terraform apply -auto-approve
	@cd terraform && terraform init && terraform plan -var-file='.prd.tfvars' -var-file='.secret.tfvars'

.PHONY: redeploy-image
redeploy-image:
	@cd terraform && tflocal apply -target=module.ecr -auto-approve

.PHONY: list-ecs-services
list-ecs-services:
	@awslocal ecs list-services --cluster hummingbird-ecs-cluster

.PHONY: list-ecs-tasks
list-ecs-tasks:
	@awslocal ecs list-tasks --cluster hummingbird-ecs-cluster

.PHONY: get-ecs-task-ips
get-ecs-task-ips:
	@awslocal ecs list-tasks --cluster hummingbird-ecs-cluster --query 'taskArns' --output text | xargs -S1024 -I {} \
	 awslocal ecs describe-tasks --cluster hummingbird-ecs-cluster --tasks {} \
			--query 'tasks[*].attachments[*].details[?name==`privateIPv4Address`].value' --output text

.PHONY: get-alb-target-ips
get-alb-target-ips:
	@awslocal elbv2 describe-load-balancers --names hummingbird-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text | xargs -S1024 -I {} \
	 awslocal elbv2 describe-target-groups --load-balancer-arn {} --query 'TargetGroups[*].TargetGroupArn' --output text | xargs -S1024 -I {} \
	 awslocal elbv2 describe-target-health --target-group-arn {}
