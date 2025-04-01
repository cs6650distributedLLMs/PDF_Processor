#!/bin/bash
set -eo pipefail

zip function.zip lambda.mjs

awslocal iam create-role \
  --role-name my-lambda-role \
  --assume-role-policy-document file://lambda-role.json

awslocal iam attach-role-policy \
  --role-name my-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

awslocal iam create-policy \
  --policy-name my-lambda-policy \
  --policy-document file://lambda-policy.json

awslocal iam attach-role-policy \
  --role-name my-lambda-role \
  --policy-arn arn:aws:iam::000000000000:policy/my-lambda-policy

awslocal lambda create-function \
    --function-name my-lambda-function \
    --runtime nodejs22.x \
    --zip-file fileb://function.zip \
    --handler lambda.handler \
    --role arn:aws:iam::000000000000:role/my-lambda-role
