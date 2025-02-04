#!/usr/bin/env sh

set -x

echo "Creating media S3 bucket"
awslocal s3 mb s3://media --region ca-west-1

echo "Creating media DynamoDB table"
awslocal dynamodb create-table \
  --region ca-west-1 \
  --table-name media \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S \
    AttributeName=SK,AttributeType=S \
  --key-schema \
    AttributeName=PK,KeyType=HASH \
    AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --table-class STANDARD
