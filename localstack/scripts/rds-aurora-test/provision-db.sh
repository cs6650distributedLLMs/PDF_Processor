#!/bin/bash
set -eo pipefail

DB_CLUSTER_ARN=$(awslocal rds create-db-cluster \
    --db-cluster-identifier hummingbird-test-db-cluster \
    --engine aurora-postgresql \
    --database-name hummingbird \
    --master-username admin \
    --master-user-password admin \
    --query "DBCluster.DBClusterArn" \
    --output text)

awslocal rds create-db-instance \
    --db-instance-identifier hummingbird-test-db \
    --db-cluster-identifier hummingbird-test-db-cluster \
    --engine aurora-postgresql \
    --db-instance-class db.r8g.48xlarge > /dev/null

SECRET_ARN=$(awslocal secretsmanager create-secret \
    --name hummingbird-db-creds \
    --secret-string file://db-creds.json \
    --query "ARN" \
    --output text)

awslocal rds-data execute-statement \
    --database hummingbird \
    --resource-arn $DB_CLUSTER_ARN \
    --secret-arn $SECRET_ARN \
    --sql 'SELECT 123' \
    --output text
