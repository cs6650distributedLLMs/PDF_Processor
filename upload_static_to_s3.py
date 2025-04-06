#!/usr/bin/env python3
"""
Script to upload static assets to S3 for the PDF Processor application.
This allows you to serve static files from S3/CloudFront instead of from Lambda.
"""

import os
import mimetypes
import boto3
from botocore.exceptions import ClientError

# Settings
STATIC_DIR = 'static'  # Directory containing static files
S3_BUCKET = os.environ.get('STATIC_BUCKET')  # Get bucket name from environment
S3_PREFIX = 'static/'  # Prefix for S3 keys

def upload_file(file_path, bucket, object_name=None):
    """Upload a file to an S3 bucket

    Args:
        file_path (str): Path to the file to upload
        bucket (str): Bucket to upload to
        object_name (str, optional): S3 object name. If not specified, file_path is used

    Returns:
        bool: True if file was uploaded, else False
    """
    # If S3 object_name not specified, use file_path
    if object_name is None:
        object_name = file_path

    # Add prefix
    object_name = S3_PREFIX + object_name.replace('\\', '/')

    # Get content type
    content_type = mimetypes.guess_type(file_path)[0]
    if content_type is None:
        content_type = 'application/octet-stream'

    # Upload the file
    s3_client = boto3.client('s3')
    try:
        extra_args = {
            'ContentType': content_type,
            'CacheControl': 'max-age=86400'  # Cache for 1 day
        }
        s3_client.upload_file(file_path, bucket, object_name, ExtraArgs=extra_args)
        print(f"Uploaded {file_path} to s3://{bucket}/{object_name}")
    except ClientError as e:
        print(f"Error: {e}")
        return False
    return True

def upload_directory(directory, bucket):
    """Upload all files in a directory to S3

    Args:
        directory (str): Directory to upload
        bucket (str): S3 bucket name

    Returns:
        int: Number of files uploaded
    """
    count = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            full_path = os.path.join(root, file)
            
            # Create relative path
            rel_path = os.path.relpath(full_path, os.path.dirname(directory))
            
            # Upload file
            if upload_file(full_path, bucket, rel_path):
                count += 1
    
    return count

def main():
    """Main function"""
    if not S3_BUCKET:
        print("Error: STATIC_BUCKET environment variable not set")
        print("Usage: STATIC_BUCKET=your-bucket-name python upload_static_to_s3.py")
        return
    
    # Check if the static directory exists
    if not os.path.isdir(STATIC_DIR):
        print(f"Error: Static directory '{STATIC_DIR}' not found")
        return
    
    # Upload all files
    count = upload_directory(STATIC_DIR, S3_BUCKET)
    print(f"Successfully uploaded {count} files to s3://{S3_BUCKET}/{S3_PREFIX}")
    
    # Print CloudFront URL if available
    cloudfront_domain = os.environ.get('CLOUDFRONT_DOMAIN')
    if cloudfront_domain:
        print(f"Files are available at: https://{cloudfront_domain}/{S3_PREFIX}")
    else:
        print(f"Files are available at: https://{S3_BUCKET}.s3.amazonaws.com/{S3_PREFIX}")

if __name__ == "__main__":
    main()