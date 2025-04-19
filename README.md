# Tldr - PDF Processing Service

Tldr is a Go-based microservice for PDF document processing. It handles document uploads, manages metadata, and coordinates with external services for text extraction and summarization.

## Overview

This service is responsible for:

- Generating unique IDs for uploaded documents
- Storing document content and metadata in DynamoDB
- Managing the document processing workflow
- Providing a RESTful API for document operations

## Architecture

Tldr works with two external microservices:

1. **PDF Extractor Service**: Extracts text from PDF documents
2. **Text Summarizer Service**: Generates summaries of extracted text

## User Flow

The typical usage flow is:

1. User uploads a PDF document

   - The service saves the PDF content in DynamoDB
   - The PDF is sent to the Extractor Service as base64
   - A documentId is returned to the user

2. User requests the extracted text

   - If extraction is complete, the text is returned
   - If extraction is still processing, a status message is returned

3. User requests a summary of the document

   - The service checks if extraction is complete
   - If complete, it sends the text to the Summarizer Service
   - A processing status is returned to the user

4. User downloads the summary
   - If summarization is complete, the summary is returned
   - If summarization is still processing, a status message is returned

## Building the Application

### Prerequisites

- Go 1.24.2
- AWS credentials configured for DynamoDB access
- Environment variables set (see Configuration section)

### Build Steps

```bash
# Install dependencies
go mod download

# Build the application
go build -o tldr ./cmd/server

# Run the application with required NODE_ID
NODE_ID=1 ./tldr
```

### Docker Build

```bash
# Build Docker image
docker build -t tldr .

# Run Docker container with environment variables
docker run -p 8080:8080 --env-file .env tldr
```

## Configuration

Tldr uses environment variables for configuration. Create a `.env` file in the root directory:

```bash
# Application settings
APP_ENV=development
APP_PORT=8080
GIN_MODE=debug
NODE_ID=1  # Required - unique ID for this instance (0-1023)

# AWS settings
AWS_REGION=us-east-1
DOCUMENT_DYNAMODB_TABLE_NAME=your-table-name

# External service URLs
PDF_EXTRACTOR_SERVICE_URL=http://extractor-service:8081
TEXT_SUMMARIZER_SERVICE_URL=http://summarizer-service:8082
```

> **IMPORTANT**: The `NODE_ID` environment variable is mandatory and must be unique for each instance of the application. Valid values are 0-1023.

## API Endpoints

### Document Operations

| Method | Endpoint                    | Description                          |
| ------ | --------------------------- | ------------------------------------ |
| POST   | /v1/documents               | Upload a new PDF document            |
| GET    | /v1/documents/:id           | Get document metadata                |
| GET    | /v1/documents/:id/status    | Check document processing status     |
| GET    | /v1/documents/:id/text      | Get extracted text from the document |
| POST   | /v1/documents/:id/summarize | Request document summarization       |
| GET    | /v1/documents/:id/download  | Download the summary                 |
| DELETE | /v1/documents/:id           | Delete a document                    |
| GET    | /v1/documents               | List all documents                   |

### Health Check

| Method | Endpoint | Description          |
| ------ | -------- | -------------------- |
| GET    | /health  | Service health check |

## File Size Limitation

The service has a file size limit of 370KB for PDF uploads. This limitation is due to:

1. The service stores file data directly in DynamoDB
2. DynamoDB has size limitations for items
3. Performance considerations for processing

## Status Lifecycle

Documents go through the following status transitions:

1. `PENDING` - Document uploaded but not yet processed
2. `PROCESSING` - Document is being processed by external services
3. `EXTRACTED` - Text extraction is complete
4. `SUMMARIZED` - Summarization is complete
5. `ERROR` - An error occurred during processing
