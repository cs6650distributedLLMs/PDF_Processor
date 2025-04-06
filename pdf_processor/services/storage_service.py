import os
import boto3
import tempfile
from werkzeug.utils import secure_filename

# Initialize S3 client
s3 = boto3.client('s3')

# Get bucket names from environment variables
PDF_BUCKET = os.environ.get('PDF_BUCKET', 'pdf-processor-pdfs')
TEXT_BUCKET = os.environ.get('TEXT_BUCKET', 'pdf-processor-texts')
SUMMARY_BUCKET = os.environ.get('SUMMARY_BUCKET', 'pdf-processor-summaries')

def save_file(file_obj, folder, filename=None):
    """
    Save a file to S3 or local storage depending on environment
    
    Args:
        file_obj: Flask file object or file-like object
        folder (str): Target folder path or S3 prefix
        filename (str, optional): Filename to use. If None, uses the original filename.
        
    Returns:
        str: Full path to the saved file (S3 URI or local path)
    """
    # Use provided filename or secure the original one
    if filename is None:
        if hasattr(file_obj, 'filename'):
            filename = secure_filename(file_obj.filename)
        else:
            filename = secure_filename('uploaded_file.pdf')
    else:
        filename = secure_filename(filename)
    
    # Check if we're running in AWS Lambda
    if 'AWS_LAMBDA_FUNCTION_NAME' in os.environ:
        # Save to S3
        bucket = PDF_BUCKET
        key = f"{folder.strip('/')}/{filename}"
        
        # Handle file-like objects vs Flask file objects
        if hasattr(file_obj, 'read'):
            # File-like object
            s3.upload_fileobj(file_obj, bucket, key)
        else:
            # Assume it's a path
            s3.upload_file(file_obj, bucket, key)
            
        return f"s3://{bucket}/{key}"
    else:
        # Local filesystem (for development)
        os.makedirs(folder, exist_ok=True)
        file_path = os.path.join(folder, filename)
        
        if hasattr(file_obj, 'save'):
            # Flask file object
            file_obj.save(file_path)
        elif hasattr(file_obj, 'read'):
            # File-like object
            with open(file_path, 'wb') as f:
                f.write(file_obj.read())
        else:
            # Assume it's a path
            import shutil
            shutil.copy(file_obj, file_path)
            
        return file_path

def get_file_path(folder, filename):
    """
    Get the full path for a file
    
    Args:
        folder (str): Folder path or S3 prefix
        filename (str): Filename
        
    Returns:
        str: Full path to the file (S3 URI or local path)
    """
    if 'AWS_LAMBDA_FUNCTION_NAME' in os.environ:
        bucket = determine_bucket(folder)
        key = f"{folder.strip('/')}/{secure_filename(filename)}"
        return f"s3://{bucket}/{key}"
    else:
        return os.path.join(folder, secure_filename(filename))

def delete_file(file_path):
    """
    Delete a file from S3 or local storage
    
    Args:
        file_path (str): Path to the file to delete (S3 URI or local path)
        
    Returns:
        bool: True if deleted, False if file not found
    """
    if file_path.startswith('s3://'):
        # S3 path
        parts = file_path[5:].split('/', 1)
        bucket = parts[0]
        key = parts[1]
        
        try:
            s3.delete_object(Bucket=bucket, Key=key)
            return True
        except Exception as e:
            print(f"Error deleting S3 file {file_path}: {e}")
            return False
    else:
        # Local path
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
                return True
            return False
        except Exception as e:
            print(f"Error deleting local file {file_path}: {e}")
            return False

def read_file(file_path):
    """
    Read a file from S3 or local storage
    
    Args:
        file_path (str): Path to the file to read (S3 URI or local path)
        
    Returns:
        bytes: File content
    """
    if file_path.startswith('s3://'):
        # S3 path
        parts = file_path[5:].split('/', 1)
        bucket = parts[0]
        key = parts[1]
        
        response = s3.get_object(Bucket=bucket, Key=key)
        return response['Body'].read()
    else:
        # Local path
        with open(file_path, 'rb') as f:
            return f.read()

def write_file(file_path, content, content_type=None):
    """
    Write content to a file in S3 or local storage
    
    Args:
        file_path (str): Path to write to (S3 URI or local path)
        content (bytes or str): Content to write
        content_type (str, optional): Content type (for S3)
        
    Returns:
        str: Path to the written file
    """
    # Convert string to bytes if needed
    if isinstance(content, str):
        content = content.encode('utf-8')
        if content_type is None:
            content_type = 'text/plain'
    
    if file_path.startswith('s3://'):
        # S3 path
        parts = file_path[5:].split('/', 1)
        bucket = parts[0]
        key = parts[1]
        
        extra_args = {}
        if content_type:
            extra_args['ContentType'] = content_type
        
        s3.put_object(Bucket=bucket, Key=key, Body=content, **extra_args)
        return file_path
    else:
        # Local path
        # Create directory if it doesn't exist
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        
        with open(file_path, 'wb') as f:
            f.write(content)
        return file_path

def download_to_temp(file_path):
    """
    Download a file from S3 to a temporary file
    
    Args:
        file_path (str): S3 URI or local path
        
    Returns:
        str: Path to the temporary file
    """
    if file_path.startswith('s3://'):
        # S3 path
        parts = file_path[5:].split('/', 1)
        bucket = parts[0]
        key = parts[1]
        
        # Create a temporary file
        suffix = os.path.splitext(key)[-1]
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        temp_path = temp_file.name
        temp_file.close()
        
        # Download to the temp file
        s3.download_file(bucket, key, temp_path)
        return temp_path
    else:
        # If it's already a local path, just return it
        return file_path

def determine_bucket(folder):
    """
    Determine which bucket to use based on the folder path
    
    Args:
        folder (str): Folder path or prefix
        
    Returns:
        str: Bucket name
    """
    folder_lower = folder.lower()
    if 'pdf' in folder_lower or 'upload' in folder_lower:
        return PDF_BUCKET
    elif 'text' in folder_lower:
        return TEXT_BUCKET
    elif 'summar' in folder_lower:
        return SUMMARY_BUCKET
    else:
        return PDF_BUCKET  # Default