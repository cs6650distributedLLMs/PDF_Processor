import os
import json
import tempfile
from storage_service import download_to_temp, write_file

# MinerU imports
from magic_pdf.data.data_reader_writer import FileBasedDataWriter, FileBasedDataReader
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod

def extract_text_from_pdf(pdf_path):
    """
    Extract text from PDF using MinerU OCR technology and save JSON results to output/{document_id}/ directory
    
    Args:
        pdf_path (str): Path to the PDF file (can be S3 URI or local path)
        
    Returns:
        str: Extracted text from the PDF
    """
    print(f"Processing PDF: {pdf_path}")
    
    # If PDF path is S3 URI, download to temp file
    local_pdf_path = download_to_temp(pdf_path)
    
    try:
        # Get the PDF filename without extension
        pdf_filename = os.path.basename(local_pdf_path)
        document_id = os.path.splitext(pdf_filename)[0]
        
        # Create temporary directories for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            # Set up output directories with document_id
            output_base_dir = os.path.join(temp_dir, document_id)
            local_image_dir = os.path.join(output_base_dir, "images")
            local_md_dir = os.path.join(output_base_dir, "md")
            image_dir = "images"  # Relative path for markdown
            
            # Create directories
            os.makedirs(output_base_dir, exist_ok=True)
            os.makedirs(local_image_dir, exist_ok=True)
            os.makedirs(local_md_dir, exist_ok=True)
            
            # Create writers for saving output
            image_writer = FileBasedDataWriter(local_image_dir)
            md_writer = FileBasedDataWriter(local_md_dir)
            
            # Read PDF content
            reader = FileBasedDataReader("")
            pdf_bytes = reader.read(local_pdf_path)  # read the pdf content
            
            # Create Dataset Instance
            ds = PymuDocDataset(pdf_bytes)
            
            # Process based on PDF type
            if ds.classify() == SupportedPdfParseMethod.OCR:
                print("Using OCR mode for this PDF")
                infer_result = ds.apply(doc_analyze, ocr=True)
                pipe_result = infer_result.pipe_ocr_mode(image_writer)
            else:
                print("Using text extraction mode for this PDF")
                infer_result = ds.apply(doc_analyze, ocr=False)
                pipe_result = infer_result.pipe_txt_mode(image_writer)
            
            # Generate and save output files
            model_pdf_path = os.path.join(local_md_dir, f"{document_id}_model.pdf")
            layout_pdf_path = os.path.join(local_md_dir, f"{document_id}_layout.pdf")
            spans_pdf_path = os.path.join(local_md_dir, f"{document_id}_spans.pdf")
            infer_result.draw_model(model_pdf_path)
            pipe_result.draw_layout(layout_pdf_path)
            pipe_result.draw_span(spans_pdf_path)
            
            # Get markdown content
            md_content = pipe_result.get_markdown(image_dir)
            
            # Dump markdown to file
            md_file_path = f"{document_id}.md"
            pipe_result.dump_md(md_writer, md_file_path, image_dir)
            
            # Get content list and middle json
            content_list = pipe_result.get_content_list(image_dir)
            middle_json = pipe_result.get_middle_json()
            
            # Save processed files in temporary directory
            raw_json_path = os.path.join(output_base_dir, f"{document_id}_content.json")
            with open(raw_json_path, "w", encoding="utf-8") as f:
                json.dump(content_list, f, ensure_ascii=False, indent=2)
            
            middle_raw_path = os.path.join(output_base_dir, f"{document_id}_middle.json")
            if not isinstance(middle_json, str):
                with open(middle_raw_path, "w", encoding="utf-8") as f:
                    json.dump(middle_json, f, ensure_ascii=False, indent=2)
            else:
                with open(middle_raw_path, "w", encoding="utf-8") as f:
                    f.write(middle_json)
            
            # Read the full extracted text from the markdown file
            md_file_path = os.path.join(local_md_dir, md_file_path)
            with open(md_file_path, "r", encoding="utf-8") as f:
                extracted_text = f.read()
            
            # If running in Lambda, store important files to S3
            if 'AWS_LAMBDA_FUNCTION_NAME' in os.environ:
                # Determine S3 paths based on input path
                if pdf_path.startswith('s3://'):
                    # Extract bucket and document_id from the pdf_path
                    parts = pdf_path[5:].split('/', 1)
                    bucket = parts[0]
                    
                    # Determine output prefix based on document_id
                    output_prefix = f"output/{document_id}"
                    
                    # Upload important files to S3
                    s3_md_path = f"s3://{bucket}/{output_prefix}/{document_id}.md"
                    s3_content_path = f"s3://{bucket}/{output_prefix}/{document_id}_content.json"
                    
                    # Use storage_service to write files
                    write_file(s3_md_path, extracted_text, "text/markdown")
                    
                    # Read and upload content JSON
                    with open(raw_json_path, "r", encoding="utf-8") as f:
                        content_json = f.read()
                    write_file(s3_content_path, content_json, "application/json")
            
            return extracted_text
    except Exception as e:
        print(f"Error extracting text with MinerU: {e}")
        # Fall back to basic text extraction if MinerU fails
        return _fallback_text_extraction(local_pdf_path)
    finally:
        # Delete temporary file if we created one
        if local_pdf_path != pdf_path and os.path.exists(local_pdf_path):
            os.unlink(local_pdf_path)

def _fallback_text_extraction(pdf_path):
    """
    Fallback method for text extraction if MinerU fails
    
    Args:
        pdf_path (str): Path to the PDF file
        
    Returns:
        str: Extracted text from the PDF using basic methods
    """
    try:
        import fitz  # PyMuPDF
        print("Using fallback text extraction with PyMuPDF")
        extracted_text = ""
        
        # Create fallback temporary directory
        with tempfile.TemporaryDirectory() as fallback_dir:
            document_id = os.path.splitext(os.path.basename(pdf_path))[0]
            
            # Open the PDF
            doc = fitz.open(pdf_path)
            
            # Process each page
            for page_num, page in enumerate(doc):
                print(f"Processing page {page_num + 1}/{len(doc)}")
                
                # Extract text directly
                text = page.get_text()
                extracted_text += text + "\n\n"
                
                # Save individual page text
                page_file = os.path.join(fallback_dir, f"page_{page_num+1}.txt")
                with open(page_file, "w", encoding="utf-8") as f:
                    f.write(text)
            
            # Close the document
            doc.close()
            
            # Save full text to fallback directory
            full_text_path = os.path.join(fallback_dir, f"{document_id}_full_text.txt")
            with open(full_text_path, "w", encoding="utf-8") as f:
                f.write(extracted_text)
                
            # If running in Lambda, store extracted text to S3
            if 'AWS_LAMBDA_FUNCTION_NAME' in os.environ and pdf_path.startswith('s3://'):
                parts = pdf_path[5:].split('/', 1)
                bucket = parts[0]
                output_prefix = f"output/{document_id}/fallback"
                s3_text_path = f"s3://{bucket}/{output_prefix}/{document_id}_full_text.txt"
                write_file(s3_text_path, extracted_text, "text/plain")
            
            print(f"Saved fallback extraction to temporary directory")
            return extracted_text.strip()
    except Exception as e:
        print(f"Fallback extraction also failed: {e}")
        return "Error: Unable to extract text from the PDF document."