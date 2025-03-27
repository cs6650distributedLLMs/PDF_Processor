#!/bin/bash
set -eo pipefail

ALB_ARN=$(awslocal elbv2 describe-load-balancers --query 'LoadBalancers[0].LoadBalancerArn' --output text --names hummingbird-alb)

TARGET_GROUP=$(awslocal elbv2 describe-target-groups --query 'TargetGroups[*].TargetGroupArn' --output text --load-balancer-arn $ALB_ARN)

awslocal elbv2 describe-target-health --target-group-arn $TARGET_GROUP --output table
