import os
import uuid
from flask import Flask, request, render_template, redirect, url_for, flash, jsonify
from werkzeug.utils import secure_filename

from services.ocr_service import extract_text_from_pdf
from services.summary_service import generate_summary
from services.storage_service import save_file
from services.message_service import MessageQueue

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-key-for-local-testing")
app.config["UPLOAD_FOLDER"] = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "uploads/pdfs"
)
app.config["TEXT_FOLDER"] = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "uploads/text"
)
app.config["SUMMARY_FOLDER"] = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "uploads/summaries"
)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024  # 16MB max upload size

# Ensure upload directories exist
for folder in [
    app.config["UPLOAD_FOLDER"],
    app.config["TEXT_FOLDER"],
    app.config["SUMMARY_FOLDER"],
]:
    os.makedirs(folder, exist_ok=True)

# Simple in-memory job tracking
processing_jobs = {}

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
        processing_jobs[job_id] = {
            "status": "uploaded",
            "pdf_path": pdf_path,
            "filename": filename,
            "text_path": None,
            "summary_path": None,
        }

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
    if job_id not in processing_jobs:
        flash("Job not found")
        return redirect(url_for("index"))

    job = processing_jobs[job_id]
    return render_template("results.html", job=job, job_id=job_id)


@app.route("/api/status/<job_id>")
def api_status(job_id):
    if job_id not in processing_jobs:
        return jsonify({"error": "Job not found"}), 404

    return jsonify(processing_jobs[job_id])


@app.route("/api/summary/<job_id>")
def get_summary(job_id):
    if job_id not in processing_jobs:
        return jsonify({"error": "Job not found"}), 404

    job = processing_jobs[job_id]

    if job["status"] != "completed" or not job["summary_path"]:
        return jsonify({"error": "Summary not available yet"}), 400

    with open(job["summary_path"], "r") as f:
        summary = f.read()

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
                processing_jobs[job_id]["status"] = "ocr_processing"

                # Extract text from PDF
                text_filename = f"{job_id}_extracted_text.txt"
                text_path = os.path.join(app.config["TEXT_FOLDER"], text_filename)

                # Perform OCR
                extracted_text = extract_text_from_pdf(pdf_path)

                # Save extracted text
                with open(text_path, "w", encoding="utf-8") as f:
                    f.write(extracted_text)

                # Update job status
                processing_jobs[job_id]["status"] = "ocr_completed"
                processing_jobs[job_id]["text_path"] = text_path

                # Add to summary processing queue
                summary_queue.add_message({"job_id": job_id, "text_path": text_path})

                # Process summary queue
                process_summary_queue()

            except Exception as e:
                processing_jobs[job_id]["status"] = "ocr_failed"
                processing_jobs[job_id]["error"] = str(e)
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
                processing_jobs[job_id]["status"] = "summarizing"

                # Read extracted text
                with open(text_path, "r", encoding="utf-8") as f:
                    extracted_text = f.read()

                # Generate summary
                summary = generate_summary(extracted_text)

                # Save summary
                summary_filename = f"{job_id}_summary.txt"
                summary_path = os.path.join(
                    app.config["SUMMARY_FOLDER"], summary_filename
                )

                with open(summary_path, "w", encoding="utf-8") as f:
                    f.write(summary)

                # Update job status
                processing_jobs[job_id]["status"] = "completed"
                processing_jobs[job_id]["summary_path"] = summary_path

            except Exception as e:
                processing_jobs[job_id]["status"] = "summarization_failed"
                processing_jobs[job_id]["error"] = str(e)
                print(f"Summarization error: {e}")

    thread = threading.Thread(target=worker)
    thread.daemon = True
    thread.start()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8000)
