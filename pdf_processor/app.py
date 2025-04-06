import os
import uuid
from flask import Flask, request, render_template, redirect, url_for, flash, jsonify
from werkzeug.utils import secure_filename
from services.ocr_service import extract_text_from_pdf
from services.summary_service import generate_summary
from services.storage_service import save_file, read_file, write_file
from services.message_service import MessageQueue

# Determine if we're running in AWS Lambda
is_lambda = 'AWS_LAMBDA_FUNCTION_NAME' in os.environ

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-key-for-local-testing")

# Configure upload paths - use environment variables if available (for Lambda)
app.config["UPLOAD_FOLDER"] = os.environ.get(
    "UPLOAD_FOLDER", 
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads/pdfs")
)
app.config["TEXT_FOLDER"] = os.environ.get(
    "TEXT_FOLDER",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads/text")
)
app.config["SUMMARY_FOLDER"] = os.environ.get(
    "SUMMARY_FOLDER",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads/summaries")
)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16MB max upload size

# Ensure upload directories exist (for local development)
if not is_lambda:
    for folder in [
        app.config["UPLOAD_FOLDER"],
        app.config["TEXT_FOLDER"],
        app.config["SUMMARY_FOLDER"],
    ]:
        os.makedirs(folder, exist_ok=True)

# Initialize database - DynamoDB in Lambda, in-memory dict in development
if is_lambda:
    import boto3
    from botocore.exceptions import ClientError
    
    # Initialize DynamoDB for job tracking
    dynamodb = boto3.resource('dynamodb')
    jobs_table = dynamodb.Table(os.environ.get('JOBS_TABLE', 'pdf-processor-jobs'))
    
    def get_job(job_id):
        """Get job from DynamoDB"""
        try:
            response = jobs_table.get_item(Key={'job_id': job_id})
            return response.get('Item')
        except ClientError as e:
            print(f"Error getting job {job_id}: {e}")
            return None
    
    def update_job(job_id, status, **kwargs):
        """Update job in DynamoDB"""
        import time
        
        update_expr = "set #status = :status, updated_at = :updated_at"
        expr_names = {'#status': 'status'}
        expr_values = {
            ':status': status,
            ':updated_at': int(time.time())
        }
        
        for key, value in kwargs.items():
            update_expr += f", {key} = :{key}"
            expr_values[f":{key}"] = value
        
        try:
            jobs_table.update_item(
                Key={'job_id': job_id},
                UpdateExpression=update_expr,
                ExpressionAttributeNames=expr_names,
                ExpressionAttributeValues=expr_values
            )
        except ClientError as e:
            print(f"Error updating job {job_id}: {e}")
    
    def create_job(job_id, pdf_path, filename):
        """Create job in DynamoDB"""
        import time
        
        item = {
            'job_id': job_id,
            'status': 'uploaded',
            'pdf_path': pdf_path,
            'filename': filename,
            'created_at': int(time.time()),
            'updated_at': int(time.time())
        }
        
        try:
            jobs_table.put_item(Item=item)
        except ClientError as e:
            print(f"Error creating job {job_id}: {e}")
else:
    # Simple in-memory job tracking for development
    processing_jobs = {}
    
    def get_job(job_id):
        """Get job from memory"""
        return processing_jobs.get(job_id)
    
    def update_job(job_id, status, **kwargs):
        """Update job in memory"""
        if job_id in processing_jobs:
            processing_jobs[job_id]['status'] = status
            processing_jobs[job_id].update(kwargs)
    
    def create_job(job_id, pdf_path, filename):
        """Create job in memory"""
        processing_jobs[job_id] = {
            "status": "uploaded",
            "pdf_path": pdf_path,
            "filename": filename,
            "text_path": None,
            "summary_path": None,
        }

# Create message queues
ocr_queue = MessageQueue()
summary_queue = MessageQueue()

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() == "pdf"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/upload", methods=["POST"])
def upload_file():
    if "file" not in request.files:
        flash("No file part")
        return redirect(request.url)
        
    file = request.files["file"]
    
    if file.filename == "":
        flash("No selected file")
        return redirect(request.url)
        
    if file and allowed_file(file.filename):
        # Generate a unique ID for this job
        job_id = str(uuid.uuid4())
        
        # Create secure filename and save the file
        filename = secure_filename(file.filename)
        pdf_path = save_file(file, app.config["UPLOAD_FOLDER"], f"{job_id}_{filename}")
        
        # Add job to tracking
        create_job(job_id, pdf_path, filename)
        
        # Add to OCR processing queue
        ocr_queue.add_message(
            {"job_id": job_id, "pdf_path": pdf_path, "filename": filename}
        )
        
        # Start OCR processing in a non-blocking way
        process_ocr_queue()
        
        return redirect(url_for("status", job_id=job_id))
        
    flash("File type not allowed. Please upload a PDF.")
    return redirect(url_for("index"))

@app.route("/status/<job_id>")
def status(job_id):
    job = get_job(job_id)
    
    if not job:
        flash("Job not found")
        return redirect(url_for("index"))
        
    return render_template("results.html", job=job, job_id=job_id)

@app.route("/api/status/<job_id>")
def api_status(job_id):
    job = get_job(job_id)
    
    if not job:
        return jsonify({"error": "Job not found"}), 404
        
    return jsonify(job)

@app.route("/api/summary/<job_id>")
def get_summary(job_id):
    job = get_job(job_id)
    
    if not job:
        return jsonify({"error": "Job not found"}), 404
        
    if job["status"] != "completed" or not job.get("summary_path"):
        return jsonify({"error": "Summary not available yet"}), 400
        
    # Read summary from file or S3
    summary = read_file(job["summary_path"]).decode('utf-8')
    
    return jsonify({"summary": summary})

def process_ocr_queue():
    """
    Process the OCR queue in a non-blocking way
    In a production environment, this would be a separate worker process
    """
    import threading
    
    def worker():
        while not ocr_queue.is_empty():
            message = ocr_queue.get_message()
            job_id = message["job_id"]
            pdf_path = message["pdf_path"]
            
            try:
                # Update job status
                update_job(job_id, "ocr_processing")
                
                # Extract text from PDF
                text_filename = f"{job_id}_extracted_text.txt"
                text_path = os.path.join(app.config["TEXT_FOLDER"], text_filename)
                
                # If using S3, create appropriate S3 path
                if is_lambda and pdf_path.startswith('s3://'):
                    parts = pdf_path[5:].split('/', 1)
                    bucket = parts[0]
                    text_path = f"s3://{bucket}/text/{job_id}/{text_filename}"
                
                # Perform OCR
                extracted_text = extract_text_from_pdf(pdf_path)
                
                # Save extracted text
                write_file(text_path, extracted_text)
                
                # Update job status
                update_job(job_id, "ocr_completed", text_path=text_path)
                
                # Add to summary processing queue
                summary_queue.add_message({"job_id": job_id, "text_path": text_path})
                
                # Process summary queue
                process_summary_queue()
            except Exception as e:
                update_job(job_id, "ocr_failed", error=str(e))
                print(f"OCR processing error: {e}")
    
    thread = threading.Thread(target=worker)
    thread.daemon = True
    thread.start()

def process_summary_queue():
    """
    Process the summary queue in a non-blocking way
    In a production environment, this would be a separate worker process
    """
    import threading
    
    def worker():
        while not summary_queue.is_empty():
            message = summary_queue.get_message()
            job_id = message["job_id"]
            text_path = message["text_path"]
            
            try:
                # Update job status
                update_job(job_id, "summarizing")
                
                # Read extracted text
                extracted_text = read_file(text_path).decode('utf-8')
                
                # Generate summary
                summary = generate_summary(extracted_text)
                
                # Save summary
                summary_filename = f"{job_id}_summary.txt"
                summary_path = os.path.join(
                    app.config["SUMMARY_FOLDER"], summary_filename
                )
                
                # If using S3, create appropriate S3 path
                if is_lambda and text_path.startswith('s3://'):
                    parts = text_path[5:].split('/', 1)
                    bucket = parts[0]
                    summary_path = f"s3://{bucket}/summary/{job_id}/{summary_filename}"
                
                write_file(summary_path, summary)
                
                # Update job status
                update_job(job_id, "completed", summary_path=summary_path)
            except Exception as e:
                update_job(job_id, "summarization_failed", error=str(e))
                print(f"Summarization error: {e}")
    
    thread = threading.Thread(target=worker)
    thread.daemon = True
    thread.start()

# This main block only runs in development, not in Lambda
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8000)