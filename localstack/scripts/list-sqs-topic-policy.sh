#!/bin/bash
set -eo pipefail

QUEUE_URL=$(awslocal sqs list-queues --query 'QueueUrls[1]' --output text)

awslocal sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names Policy --query 'Attributes.Policy' --output text | jq .
