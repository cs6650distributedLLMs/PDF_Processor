package handlers

import (
	"context"
	"fmt"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"

	"tldr/internal/clients"
	"tldr/internal/core"
	"tldr/internal/models"
)

// UploadController handles PDF uploads
func UploadController(c *gin.Context) {
	// Parse the multipart form
	if err := c.Request.ParseMultipartForm(core.MaxFileSize); err != nil {
		maxFileSize := core.ConvertBytesToKb(core.MaxFileSize)
		message := fmt.Sprintf("Failed to upload document. Max size is %.2f KB.", maxFileSize)
		core.SendResponse(c, http.StatusBadRequest, message)
		return
	}

	// Get the file from the request
	file, fileHeader, err := c.Request.FormFile("file")
	if err != nil {
		core.SendBadRequestResponse(c, "Missing file")
		return
	}
	defer file.Close()

	// Check mime type
	if fileHeader.Header.Get("Content-Type") != "application/pdf" {
		core.SendResponse(c, http.StatusBadRequest, "Invalid file type. Only PDF documents are supported.")
		return
	}

	// Generate a new document ID using Snowflake
	documentID := core.GenerateIDString()

	// Read the file contents
	buffer, err := io.ReadAll(file)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// Create a new document record in DynamoDB with the file content
	document := &models.Document{
		DocumentID: documentID,
		Size:       fileHeader.Size,
		Name:       fileHeader.Filename,
		MimeType:   fileHeader.Header.Get("Content-Type"),
		Status:     core.DocumentStatusPending,
		Content:    buffer, // Store PDF content in the database
	}

	if err := clients.CreateDocument(c.Request.Context(), document); err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// Send the file to the extractor service
	extractorClient := clients.NewExtractorClient()
	resp, err := extractorClient.ExtractText(c.Request.Context(), documentID, buffer)
	if err != nil {
		// Update document status to error
		_ = clients.SetDocumentStatus(c.Request.Context(), documentID, core.DocumentStatusError)
		core.SendErrorResponse(c, err)
		return
	}

	// Update the document status based on the extractor response
	var status core.DocumentStatus
	switch resp.Status {
	case "PROCESSING":
		status = core.DocumentStatusProcessing
	case "COMPLETE":
		status = core.DocumentStatusExtracted
	case "ERROR":
		status = core.DocumentStatusError
	default:
		status = core.DocumentStatusProcessing
	}

	if err := clients.SetDocumentStatus(c.Request.Context(), documentID, status); err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// Return the document ID
	core.SendAcceptedResponse(c, models.DocumentUploadResult{DocumentID: documentID})
}

// GetExtractedTextController gets the extracted text for a document
func GetExtractedTextController(c *gin.Context) {
	documentID := c.Param("id")

	// Get the document from DynamoDB
	document, err := clients.GetDocument(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	// Check with the extractor service for the text
	extractorClient := clients.NewExtractorClient()
	extractResp, err := extractorClient.GetExtractStatus(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// If status is not complete, return the current status
	if extractResp.Status != "COMPLETE" {
		// Update our internal status
		var status core.DocumentStatus
		switch extractResp.Status {
		case "PROCESSING":
			status = core.DocumentStatusProcessing
		case "ERROR":
			status = core.DocumentStatusError
		default:
			status = core.DocumentStatusProcessing
		}

		if document.Status != status {
			_ = clients.SetDocumentStatus(c.Request.Context(), documentID, status)
		}

		// Send the current status
		c.JSON(http.StatusAccepted, gin.H{
			"status":     extractResp.Status,
			"documentId": documentID,
			"message":    "Text extraction in progress",
		})
		return
	}

	// Update the status if needed
	if document.Status != core.DocumentStatusExtracted {
		_ = clients.SetDocumentStatus(c.Request.Context(), documentID, core.DocumentStatusExtracted)
	}

	// Return the extracted text
	c.JSON(http.StatusOK, gin.H{
		"documentId": documentID,
		"text":       extractResp.Text,
	})
}

// StatusController gets the status of a document item
func StatusController(c *gin.Context) {
	documentID := c.Param("id")

	document, err := UpdateDocumentStatus(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	core.SendOkResponse(c, models.DocumentStatus{Status: document.Status})
}

// DownloadController downloads a summarized document
func DownloadController(c *gin.Context) {
	documentID := c.Param("id")

	// Get the document from DynamoDB
	document, err := clients.GetDocument(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	// Check status with summarizer if needed
	if document.Status != core.DocumentStatusSummarized {
		summarizerClient := clients.NewSummarizerClient()
		summaryResp, err := summarizerClient.GetSummaryStatus(c.Request.Context(), documentID)
		if err != nil || (summaryResp.Status != "COMPLETE" && summaryResp.Status != "completed") {
			c.Header("Retry-After", "60")
			c.Header("Location", fmt.Sprintf("%s/v1/documents/%s/status", c.Request.Host, documentID))
			core.SendAcceptedResponse(c, gin.H{"message": "PDF summarization in progress."})
			return
		}

		// Update status if complete
		if summaryResp.Status == "COMPLETE" || summaryResp.Status == "completed" {
			document.Status = core.DocumentStatusSummarized
			_ = clients.SetDocumentStatus(c.Request.Context(), documentID, core.DocumentStatusSummarized)
		}
	}

	// Get the summary result
	summarizerClient := clients.NewSummarizerClient()
	summaryText, err := summarizerClient.GetSummaryResult(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// Set the content type and attachment headers
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s.summary.txt", core.GetBaseName(document.Name)))
	c.Header("Content-Type", "text/plain")

	// Write the summary to the response
	c.String(http.StatusOK, summaryText)
}

// SummarizeController summarizes a document
func SummarizeController(c *gin.Context) {
	documentID := c.Param("id")

	// Get the document from DynamoDB
	document, err := clients.GetDocument(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	// First, check if the text has been extracted
	extractorClient := clients.NewExtractorClient()
	extractStatus, err := extractorClient.GetExtractStatus(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// If extractor says it's not complete, update our status and return
	if extractStatus.Status != "COMPLETE" {
		// Update status based on extractor response
		var status core.DocumentStatus
		switch extractStatus.Status {
		case "PROCESSING":
			status = core.DocumentStatusProcessing
		case "ERROR":
			status = core.DocumentStatusError
		default:
			status = core.DocumentStatusProcessing
		}

		if err := clients.SetDocumentStatus(c.Request.Context(), documentID, status); err != nil {
			core.SendErrorResponse(c, err)
			return
		}

		core.SendAcceptedResponse(c, gin.H{"message": "Text extraction in progress."})
		return
	}

	// Update the document status to extracted if needed
	if document.Status != core.DocumentStatusExtracted {
		if err := clients.SetDocumentStatus(c.Request.Context(), documentID, core.DocumentStatusExtracted); err != nil {
			core.SendErrorResponse(c, err)
			return
		}
		document.Status = core.DocumentStatusExtracted
	}

	// Send the extracted text to the summarizer service
	summarizerClient := clients.NewSummarizerClient()
	summaryResp, err := summarizerClient.SummarizeText(c.Request.Context(), documentID, extractStatus.Text)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	// Update the document status based on summarizer response
	var status core.DocumentStatus
	switch summaryResp.Status {
	case "PROCESSING", "processing":
		status = core.DocumentStatusProcessing
	case "COMPLETE", "completed":
		status = core.DocumentStatusSummarized
	case "ERROR", "error":
		status = core.DocumentStatusError
	default:
		status = core.DocumentStatusProcessing
	}

	if err := clients.SetDocumentStatus(c.Request.Context(), documentID, status); err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	core.SendAcceptedResponse(c, gin.H{"documentId": documentID})
}

// GetController gets a document item
func GetController(c *gin.Context) {
	documentID := c.Param("id")

	document, err := UpdateDocumentStatus(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	// Don't return the content in the response
	document.Content = nil

	core.SendOkResponse(c, document)
}

// DeleteController deletes a document item
func DeleteController(c *gin.Context) {
	documentID := c.Param("id")

	// Get the document from DynamoDB
	document, err := clients.GetDocument(c.Request.Context(), documentID)
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	if document == nil {
		core.SendNotFoundResponse(c)
		return
	}

	// Delete the document from DynamoDB
	if _, err := clients.DeleteDocument(c.Request.Context(), documentID); err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	core.SendAcceptedResponse(c, gin.H{"documentId": documentID})
}

// ListController lists all document items
func ListController(c *gin.Context) {
	// Get all document from DynamoDB
	items, err := clients.GetAllDocument(c.Request.Context())
	if err != nil {
		core.SendErrorResponse(c, err)
		return
	}

	core.SendOkResponse(c, items)
}

// UpdateDocumentStatus checks the current processing status with external services and updates if needed
func UpdateDocumentStatus(ctx context.Context, documentID string) (*models.Document, error) {
	// Get the document from DynamoDB
	document, err := clients.GetDocument(ctx, documentID)
	if err != nil {
		return nil, err
	}

	if document == nil {
		return nil, fmt.Errorf("document not found")
	}

	// Check if we're waiting for extraction
	if document.Status == core.DocumentStatusPending || document.Status == core.DocumentStatusProcessing {
		extractorClient := clients.NewExtractorClient()
		extractResp, err := extractorClient.GetExtractStatus(ctx, documentID)
		if err == nil {
			// Update status based on extractor response
			switch extractResp.Status {
			case "COMPLETE", "completed":
				document.Status = core.DocumentStatusExtracted
				_ = clients.SetDocumentStatus(ctx, documentID, core.DocumentStatusExtracted)
			case "ERROR", "error":
				document.Status = core.DocumentStatusError
				_ = clients.SetDocumentStatus(ctx, documentID, core.DocumentStatusError)
			}
		}
	} else if document.Status == core.DocumentStatusExtracted {
		// Check if there's a pending summarization
		summarizerClient := clients.NewSummarizerClient()
		summaryResp, err := summarizerClient.GetSummaryStatus(ctx, documentID)
		if err == nil && (summaryResp.Status == "COMPLETE" || summaryResp.Status == "completed") {
			document.Status = core.DocumentStatusSummarized
			_ = clients.SetDocumentStatus(ctx, documentID, core.DocumentStatusSummarized)
		}
	}

	return document, nil
}
