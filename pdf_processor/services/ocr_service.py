import os
import json

# MinerU imports
from magic_pdf.data.data_reader_writer import FileBasedDataWriter, FileBasedDataReader
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod


def extract_text_from_pdf(pdf_path):
    """
    Extract text from PDF using MinerU OCR technology and save JSON results to output/{document_id}/ directory

    Args:
        pdf_path (str): Path to the PDF file

    Returns:
        str: Extracted text from the PDF
    """
    print(f"Processing PDF: {pdf_path}")

    try:
        # Get the PDF filename without extension
        pdf_filename = os.path.basename(pdf_path)
        document_id = os.path.splitext(pdf_filename)[0]

        # Set up output directories with document_id
        output_base_dir = os.path.join(os.getcwd(), "output", document_id)
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
        pdf_bytes = reader.read(pdf_path)  # read the pdf content

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

        # Get content list and save only as raw JSON (no duplicates)
        content_list = pipe_result.get_content_list(image_dir)

        # Get middle json
        middle_json = pipe_result.get_middle_json()

        # Save only raw JSON files directly to document_id directory
        try:
            # Save content list JSON
            raw_json_path = os.path.join(output_base_dir, f"{document_id}_content.json")
            with open(raw_json_path, "w", encoding="utf-8") as f:
                json.dump(content_list, f, ensure_ascii=False, indent=2)

            # If middle_json is not a string, save it directly
            middle_raw_path = os.path.join(
                output_base_dir, f"{document_id}_middle.json"
            )
            if not isinstance(middle_json, str):
                with open(middle_raw_path, "w", encoding="utf-8") as f:
                    json.dump(middle_json, f, ensure_ascii=False, indent=2)
            # If it's a string, it might already be JSON formatted
            else:
                with open(middle_raw_path, "w", encoding="utf-8") as f:
                    f.write(middle_json)

            print(f"Saved JSON files to: {output_base_dir}")
        except Exception as json_err:
            print(f"Warning: Could not save raw JSON files: {json_err}")

        # Read the full extracted text from the markdown file
        md_file_path = os.path.join(local_md_dir, md_file_path)
        with open(md_file_path, "r", encoding="utf-8") as f:
            extracted_text = f.read()

        return extracted_text

    except Exception as e:
        print(f"Error extracting text with MinerU: {e}")
        # Fall back to basic text extraction if MinerU fails
        return _fallback_text_extraction(pdf_path)


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

        # Create fallback output directory
        document_id = os.path.splitext(os.path.basename(pdf_path))[0]
        fallback_dir = os.path.join(os.getcwd(), "output", document_id, "fallback")
        os.makedirs(fallback_dir, exist_ok=True)

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

        print(f"Saved fallback extraction to: {fallback_dir}")

        return extracted_text.strip()

    except Exception as e:
        print(f"Fallback extraction also failed: {e}")
        return "Error: Unable to extract text from the PDF document."
