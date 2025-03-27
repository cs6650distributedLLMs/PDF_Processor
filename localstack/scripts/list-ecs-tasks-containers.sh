#!/bin/bash
set -eo pipefail

TASK_ARNS=$(awslocal ecs list-tasks --cluster hummingbird-ecs-cluster --query 'taskArns' --output text)

awslocal ecs describe-tasks --cluster hummingbird-ecs-cluster --tasks $TASK_ARNS --query 'tasks[*].containers[*].{ContainerName:name, Status:lastStatus, Port:networkBindings[0].hostPort}' --output table
