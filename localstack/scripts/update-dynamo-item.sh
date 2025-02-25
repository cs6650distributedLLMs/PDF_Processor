#!/usr/bin/env sh

set -x

awslocal dynamodb update-item \
    --table-name hummingbird-app-table \
    --key '{ 
        "PK": {"S": "MEDIA#2d76ede6-6853-4120-af82-1660e2dff053"},
        "SK": {"S": "METADATA"}
    }' \
    --update-expression "SET #status = :newStatus" \
    --condition-expression "#status = :currentStatus" \
    --expression-attribute-names '{
        "#status": "status"
    }' \
    --expression-attribute-values '{
        ":newStatus": {"S": "PENDING"},
        ":currentStatus": {"S": "COMPLETE"}
    }'
