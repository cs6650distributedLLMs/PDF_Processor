import os
import json

# MinerU imports
from magic_pdf.data.data_reader_writer import FileBasedDataWriter, FileBasedDataReader
from magic_pdf.data.dataset import PymuDocDataset
from magic_pdf.model.doc_analyze_by_custom_model import doc_analyze
from magic_pdf.config.enums import SupportedPdfParseMethod


def extract_text_from_pdf(pdf_path):
    """
    Extract text from PDF using MinerU OCR technology and save JSON results to current directory

    Args:
        pdf_path (str): Path to the PDF file

    Returns:
        str: Extracted text from the PDF
    """
    print(f"Processing PDF: {pdf_path}")

    try:
        # Set up output directories
        # Use current directory instead of temp dir
        current_dir = os.getcwd()
        local_image_dir = os.path.join(current_dir, "output_images")
        local_md_dir = current_dir
        image_dir = "output_images"  # Relative path for markdown

        os.makedirs(local_image_dir, exist_ok=True)

        # Create writers for saving output
        image_writer = FileBasedDataWriter(local_image_dir)
        md_writer = FileBasedDataWriter(local_md_dir)

        # Get the PDF filename without extension
        pdf_filename = os.path.basename(pdf_path)
        name_without_suffix = os.path.splitext(pdf_filename)[0]

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
        model_pdf_path = os.path.join(local_md_dir, f"{name_without_suffix}_model.pdf")
        layout_pdf_path = os.path.join(
            local_md_dir, f"{name_without_suffix}_layout.pdf"
        )
        spans_pdf_path = os.path.join(local_md_dir, f"{name_without_suffix}_spans.pdf")

        infer_result.draw_model(model_pdf_path)
        pipe_result.draw_layout(layout_pdf_path)
        pipe_result.draw_span(spans_pdf_path)

        # Get markdown content
        md_content = pipe_result.get_markdown(image_dir)

        # Dump markdown to file
        md_file_path = f"{name_without_suffix}.md"
        pipe_result.dump_md(md_writer, md_file_path, image_dir)

        # Get content list and save as JSON
        content_list = pipe_result.get_content_list(image_dir)
        content_list_path = f"{name_without_suffix}_content_list.json"
        pipe_result.dump_content_list(md_writer, content_list_path, image_dir)
        print(
            f"Saved content list JSON to: {os.path.join(local_md_dir, content_list_path)}"
        )

        # Get middle json and save
        middle_json = pipe_result.get_middle_json()
        middle_json_path = f"{name_without_suffix}_middle.json"
        pipe_result.dump_middle_json(md_writer, middle_json_path)
        print(f"Saved middle JSON to: {os.path.join(local_md_dir, middle_json_path)}")

        # Save raw JSON directly to current directory
        # This is in addition to MinerU's built-in JSON export
        try:
            # Save content list JSON (as a separate copy)
            with open(
                f"{name_without_suffix}_content_raw.json", "w", encoding="utf-8"
            ) as f:
                json.dump(content_list, f, ensure_ascii=False, indent=2)

            # If middle_json is not a string, save it directly
            if not isinstance(middle_json, str):
                with open(
                    f"{name_without_suffix}_middle_raw.json", "w", encoding="utf-8"
                ) as f:
                    json.dump(middle_json, f, ensure_ascii=False, indent=2)
            # If it's a string, it might already be JSON formatted
            else:
                with open(
                    f"{name_without_suffix}_middle_raw.json", "w", encoding="utf-8"
                ) as f:
                    f.write(middle_json)

            print(f"Saved raw JSON copies to current directory")
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

        # Open the PDF
        doc = fitz.open(pdf_path)

        # Process each page
        for page_num, page in enumerate(doc):
            print(f"Processing page {page_num + 1}/{len(doc)}")

            # Extract text directly
            text = page.get_text()
            extracted_text += text + "\n\n"

        # Close the document
        doc.close()

        return extracted_text.strip()

    except Exception as e:
        print(f"Fallback extraction also failed: {e}")
        return "Error: Unable to extract text from the PDF document."
