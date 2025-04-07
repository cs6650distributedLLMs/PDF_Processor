#!/bin/bash
# Script to build and deploy the PDF Processor application to AWS

set -e  # Exit on error

# Configuration
STACK_NAME=${STACK_NAME:-pdf-processor}
REGION=${AWS_REGION:-us-west-2}
DEPLOY_BUCKET=${DEPLOY_BUCKET:-}  # Bucket for SAM deployment artifacts
STATIC_BUCKET=${STATIC_BUCKET:-}  # Bucket for static assets
CLOUDFRONT_DOMAIN=${CLOUDFRONT_DOMAIN:-}  # CloudFront domain (if any)
GROK_API_KEY=${GROK_API_KEY:-}  # Grok API Key
GROK_API_URL=${GROK_API_URL:-https://api.x.ai/v1/chat/completions}  # Grok API URL

# Validate requirements
if ! command -v sam &> /dev/null; then
    echo "AWS SAM CLI is not installed. Please install it first."
    echo "See: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    echo "See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Ask for a deployment bucket if not provided
if [ -z "$DEPLOY_BUCKET" ]; then
    read -p "Enter the name of the S3 bucket for SAM deployment artifacts: " DEPLOY_BUCKET
    export DEPLOY_BUCKET=$DEPLOY_BUCKET
fi

# Ask for a static assets bucket if not provided
if [ -z "$STATIC_BUCKET" ]; then
    read -p "Enter the name of the S3 bucket for static assets: " STATIC_BUCKET
    export STATIC_BUCKET=$STATIC_BUCKET
fi

# Ask for Grok API Key if not provided
if [ -z "$GROK_API_KEY" ]; then
    read -sp "Enter your Grok API Key (input hidden): " GROK_API_KEY
    echo
    export GROK_API_KEY=$GROK_API_KEY
fi

echo "Building and deploying $STACK_NAME to region $REGION..."

# Build the SAM application
echo "Building the application..."
sam build --use-container

# Deploy static assets
if [ -d "static" ]; then
    echo "Uploading static assets to S3..."
    STATIC_BUCKET=$STATIC_BUCKET CLOUDFRONT_DOMAIN=$CLOUDFRONT_DOMAIN python upload_static_to_s3.py
else
    echo "No static directory found, skipping static asset upload."
fi

# Update templates for API Gateway
if [ -d "templates" ]; then
    echo "Would you like to update HTML templates with API Gateway URLs? (y/n)"
    read update_templates
    
    if [ "$update_templates" = "y" ]; then
        # Get the API Gateway URL from a previous deployment if available
        api_url=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text 2>/dev/null || echo "")
        
        if [ -z "$api_url" ]; then
            read -p "Enter the API Gateway URL (without trailing slash): " api_url
        else
            echo "Found API Gateway URL from previous deployment: $api_url"
            read -p "Use this URL? (y/n): " use_existing_url
            if [ "$use_existing_url" != "y" ]; then
                read -p "Enter the API Gateway URL (without trailing slash): " api_url
            fi
        fi
        
        static_url=""
        if [ -n "$CLOUDFRONT_DOMAIN" ]; then
            static_url="https://$CLOUDFRONT_DOMAIN"
        else
            static_url="https://$STATIC_BUCKET.s3.amazonaws.com"
        fi
        
        echo "Updating templates with API URL: $api_url"
        echo "Updating templates with static URL: $static_url"
        python update_templates.py --api-url "$api_url" --static-url "$static_url"
    fi
fi

# Deploy the SAM application
echo "Deploying the application..."
sam deploy \
    --stack-name $STACK_NAME \
    --s3-bucket $DEPLOY_BUCKET \
    --region $REGION \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
        GrokApiKey=$GROK_API_KEY \
        GrokApiUrl=$GROK_API_URL

echo "Deployment complete!"

# Display stack outputs
echo "Stack outputs:"
aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs" --output table

echo "You can now access your application at the API Gateway URL shown above."