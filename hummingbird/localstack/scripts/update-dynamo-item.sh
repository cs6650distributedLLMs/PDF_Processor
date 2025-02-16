#!/usr/bin/env sh

set -x

awslocal dynamodb update-item \
    --table-name hummingbird-app-table \
    --key '{ 
        "PK": {"S": "MEDIA#d89314be-cfcf-4c91-b82b-913ac74ffecc"}, 
        "SK": {"S": "METADATA"}
    }' \
    --update-expression "SET #status = :newStatus" \
    --condition-expression "#status = :currentStatus" \
    --expression-attribute-names '{
        "#status": "status"
    }' \
    --expression-attribute-values '{
        ":newStatus": {"S": "PENDING"},
        ":currentStatus": {"S": "COMPLETED"}
    }'
