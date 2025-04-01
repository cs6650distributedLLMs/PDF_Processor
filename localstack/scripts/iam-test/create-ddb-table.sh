#!/bin/bash
set -eo pipefail

awslocal dynamodb create-table \
    --table-name test-dynamo-table \
    --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
    --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
    --billing-mode PAY_PER_REQUEST \
    --region us-west-2
