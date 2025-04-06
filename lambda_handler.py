import json
import os
import base64
import boto3
from services.ocr_service import extract_text_from_pdf
from services.summary_service import generate_summary
from services.storage_service import save_file

# Initialize S3 client
s3 = boto3.client('s3')

# Configure bucket names from environment variables
PDF_BUCKET = os.environ.get('PDF_BUCKET', 'pdf-processor-pdfs')
TEXT_BUCKET = os.environ.get('TEXT_BUCKET', 'pdf-processor-texts')
SUMMARY_BUCKET = os.environ.get('SUMMARY_BUCKET', 'pdf-processor-summaries')

# DynamoDB for job tracking
dynamodb = boto3.resource('dynamodb')
jobs_table = dynamodb.Table(os.environ.get('JOBS_TABLE', 'pdf-processor-jobs'))

def lambda_handler(event, context):
    """AWS Lambda handler function for the PDF Processor application."""
    
    # Print the event for debugging
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Determine the event source and process accordingly
        if event.get('requestContext') and event.get('requestContext').get('http'):
            # API Gateway HTTP API event
            return handle_api_gateway_event(event)
        elif event.get('Records') and event.get('Records')[0].get('s3'):
            # S3 event (file uploaded)
            return handle_s3_event(event)
        elif event.get('source') == 'aws.events':
            # CloudWatch scheduled event (for processing queues)
            return process_job_queues()
        else:
            # Direct Lambda invocation
            return handle_direct_invocation(event)
    except Exception as e:
        print(f"Error processing request: {str(e)}")
        import traceback
        traceback.print_exc()
        
        # Return error response
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }

def handle_api_gateway_event(event):
    """Handle API Gateway HTTP API events"""
    
    # Get the route
    route_key = event.get('routeKey', '')
    
    # Handle different routes
    if route_key == 'POST /upload':
        return handle_pdf_upload(event)
    elif route_key.startswith('GET /status/'):
        job_id = event.get('pathParameters', {}).get('id')
        return get_job_status(job_id)
    elif route_key.startswith('GET /summary/'):
        job_id = event.get('pathParameters', {}).get('id')
        return get_job_summary(job_id)
    else:
        return {
            'statusCode': 404,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'Route not found'
            })
        }

def handle_pdf_upload(event):
    """Handle PDF upload via API Gateway"""
    
    # Check if we have a body
    if not event.get('body'):
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': 'No body in request'
            })
        }
    
    # Determine if body is base64 encoded
    is_base64 = event.get('isBase64Encoded', False)
    body = event.get('body')
    
    if is_base64:
        body = base64.b64decode(body)
        
    # Parse multipart/form-data to extract file
    # This is simplified and would need a proper multipart parser in production
    import uuid
    
    # Generate a unique job ID
    job_id = str(uuid.uuid4())
    
    # For simplicity in this example, let's assume we have the file content
    # In a real implementation, you'd need to parse the multipart form data
    file_content = body
    filename = f"{job_id}.pdf"
    
    # Save to S3
    pdf_key = f"uploads/{job_id}/{filename}"
    s3.put_object(
        Bucket=PDF_BUCKET,
        Key=pdf_key,
        Body=file_content,
        ContentType='application/pdf'
    )
    
    # Create job record
    jobs_table.put_item(
        Item={
            'job_id': job_id,
            'status': 'uploaded',
            'pdf_path': f"s3://{PDF_BUCKET}/{pdf_key}",
            'filename': filename,
            'created_at': int(time.time()),
            'updated_at': int(time.time())
        }
    )
    
    # Trigger OCR processing (via separate Lambda or this same Lambda if it can complete in time)
    # For this example, we'll return the job ID and assume another process will pick it up
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({
            'job_id': job_id,
            'status': 'uploaded',
            'message': 'PDF uploaded successfully. Processing will begin shortly.'
        })
    }

def get_job_status(job_id):
    """Get the status of a job"""
    
    try:
        # Get job from DynamoDB
        response = jobs_table.get_item(
            Key={
                'job_id': job_id
            }
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Job not found'
                })
            }
        
        job = response['Item']
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps(job)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }

def get_job_summary(job_id):
    """Get the summary for a completed job"""
    
    try:
        # Get job from DynamoDB
        response = jobs_table.get_item(
            Key={
                'job_id': job_id
            }
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Job not found'
                })
            }
        
        job = response['Item']
        
        # Check if job is completed
        if job.get('status') != 'completed' or not job.get('summary_path'):
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Summary not available yet'
                })
            }
        
        # Get summary from S3
        summary_path = job.get('summary_path')
        
        # Parse S3 path (s3://bucket/key)
        import re
        match = re.match(r's3://([^/]+)/(.+)', summary_path)
        
        if not match:
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'error': 'Invalid summary path'
                })
            }
        
        bucket = match.group(1)
        key = match.group(2)
        
        # Get summary from S3
        response = s3.get_object(
            Bucket=bucket,
            Key=key
        )
        
        summary = response['Body'].read().decode('utf-8')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'summary': summary
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }

def handle_s3_event(event):
    """Handle S3 events (file uploaded)"""
    
    # Get bucket and key from event
    record = event['Records'][0]['s3']
    bucket = record['bucket']['name']
    key = record['object']['key']
    
    # Only process if this is a PDF uploaded to the uploads folder
    if not key.startswith('uploads/') or not key.lower().endswith('.pdf'):
        print(f"Skipping non-PDF or non-upload file: {key}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'File skipped (not a PDF upload)'
            })
        }
    
    # Extract job ID from key path
    # uploads/job_id/filename.pdf
    parts = key.split('/')
    if len(parts) < 3:
        print(f"Invalid key format: {key}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Invalid key format'
            })
        }
    
    job_id = parts[1]
    
    # Update job status
    jobs_table.update_item(
        Key={
            'job_id': job_id
        },
        UpdateExpression="set #status = :status, updated_at = :updated_at",
        ExpressionAttributeNames={
            '#status': 'status'
        },
        ExpressionAttributeValues={
            ':status': 'ocr_processing',
            ':updated_at': int(time.time())
        }
    )
    
    try:
        # Download file from S3
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as temp_file:
            temp_path = temp_file.name
            
        s3.download_file(bucket, key, temp_path)
        
        # Process the PDF
        extracted_text = extract_text_from_pdf(temp_path)
        
        # Clean up temp file
        os.unlink(temp_path)
        
        # Save text to S3
        text_key = f"text/{job_id}/{job_id}_extracted_text.txt"
        s3.put_object(
            Bucket=TEXT_BUCKET,
            Key=text_key,
            Body=extracted_text.encode('utf-8'),
            ContentType='text/plain'
        )
        
        # Update job status
        jobs_table.update_item(
            Key={
                'job_id': job_id
            },
            UpdateExpression="set #status = :status, text_path = :text_path, updated_at = :updated_at",
            ExpressionAttributeNames={
                '#status': 'status'
            },
            ExpressionAttributeValues={
                ':status': 'ocr_completed',
                ':text_path': f"s3://{TEXT_BUCKET}/{text_key}",
                ':updated_at': int(time.time())
            }
        )
        
        # Generate summary
        summary = generate_summary(extracted_text)
        
        # Save summary to S3
        summary_key = f"summary/{job_id}/{job_id}_summary.txt"
        s3.put_object(
            Bucket=SUMMARY_BUCKET,
            Key=summary_key,
            Body=summary.encode('utf-8'),
            ContentType='text/plain'
        )
        
        # Update job status
        jobs_table.update_item(
            Key={
                'job_id': job_id
            },
            UpdateExpression="set #status = :status, summary_path = :summary_path, updated_at = :updated_at",
            ExpressionAttributeNames={
                '#status': 'status'
            },
            ExpressionAttributeValues={
                ':status': 'completed',
                ':summary_path': f"s3://{SUMMARY_BUCKET}/{summary_key}",
                ':updated_at': int(time.time())
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully processed PDF for job {job_id}',
                'job_id': job_id,
                'status': 'completed'
            })
        }
    except Exception as e:
        print(f"Error processing PDF: {str(e)}")
        
        # Update job status to failed
        jobs_table.update_item(
            Key={
                'job_id': job_id
            },
            UpdateExpression="set #status = :status, error = :error, updated_at = :updated_at",
            ExpressionAttributeNames={
                '#status': 'status'
            },
            ExpressionAttributeValues={
                ':status': 'failed',
                ':error': str(e),
                ':updated_at': int(time.time())
            }
        )
        
        raise e

def handle_direct_invocation(event):
    """Handle direct Lambda invocation"""
    
    # Check if we have a job ID
    job_id = event.get('job_id')
    
    if job_id:
        # Get job status
        return get_job_status(job_id)
    
    # If we have a PDF path, process it
    pdf_path = event.get('pdf_path')
    
    if pdf_path:
        # Processing logic similar to handle_s3_event but with the provided path
        # This is a simplified example
        pass
    
    return {
        'statusCode': 400,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps({
            'error': 'Invalid request'
        })
    }

def process_job_queues():
    """Process any queued jobs
    
    This would be triggered by a CloudWatch scheduled event
    to handle any jobs that need processing
    """
    
    # In a real implementation, you would:
    # 1. Query DynamoDB for jobs with status 'uploaded'
    # 2. Process each job (similar to handle_s3_event)
    # 3. Update job status in DynamoDB
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Job queue processing completed'
        })
    }

# Add missing imports
import time