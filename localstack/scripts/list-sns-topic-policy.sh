#!/bin/bash
set -eo pipefail

TOPIC_ARN=$(awslocal sns list-topics --query 'Topics[*].TopicArn' --output text)

awslocal sns get-topic-attributes --topic-arn $TOPIC_ARN --query 'Attributes.Policy' --output text | jq .
