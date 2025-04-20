package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"time"
)

// ExtractorClient is the client for the PDF extractor service
type ExtractorClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

// NewExtractorClient creates a new PDF extractor client
func NewExtractorClient() *ExtractorClient {
	return &ExtractorClient{
		BaseURL: os.Getenv("PDF_EXTRACTOR_SERVICE_URL"),
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// ExtractResponse represents a response from the PDF extractor service
type ExtractResponse struct {
	Status string `json:"status"`
	Text   string `json:"text,omitempty"`
}

// ExtractText sends a request to extract text from a PDF
func (c *ExtractorClient) ExtractText(ctx context.Context, documentID string, pdfData []byte) (*ExtractResponse, error) {
	// Create a new buffer for the multipart form
	var buf bytes.Buffer
	writer := multipart.NewWriter(&buf)

	// Add the document_id field
	err := writer.WriteField("document_id", documentID)
	if err != nil {
		return nil, fmt.Errorf("failed to add document_id to form: %w", err)
	}

	// Add the file field
	fileWriter, err := writer.CreateFormFile("file", "document.pdf")
	if err != nil {
		return nil, fmt.Errorf("failed to create form file: %w", err)
	}
	_, err = fileWriter.Write(pdfData)
	if err != nil {
		return nil, fmt.Errorf("failed to write file data: %w", err)
	}

	// Close the writer
	err = writer.Close()
	if err != nil {
		return nil, fmt.Errorf("failed to close multipart writer: %w", err)
	}

	// Create a new HTTP request to the extract endpoint
	url := fmt.Sprintf("%s/extract", c.BaseURL)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, &buf)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Send the request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Check for error status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("extractor service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var extractResp ExtractResponse
	if err := json.Unmarshal(respBody, &extractResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// Convert 'ok' response to 'processing' for consistency with our system
	if extractResp.Status == "ok" {
		extractResp.Status = "PROCESSING"
	}

	return &extractResp, nil
}

// GetExtractStatus checks the status of a document extraction
func (c *ExtractorClient) GetExtractStatus(ctx context.Context, documentID string) (*ExtractResponse, error) {
	// Create a new HTTP request to the check-status endpoint
	url := fmt.Sprintf("%s/check-status/%s", c.BaseURL, documentID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Send the request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Check for error status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("extractor service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var statusResp struct {
		Status string `json:"status"`
	}
	if err := json.Unmarshal(respBody, &statusResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// If the status is "completed", get the result
	if statusResp.Status == "completed" {
		return c.GetExtractResult(ctx, documentID)
	}

	// Map the status to our internal status
	extractResp := &ExtractResponse{}
	switch statusResp.Status {
	case "processing":
		extractResp.Status = "PROCESSING"
	case "error":
		extractResp.Status = "ERROR"
	default:
		extractResp.Status = statusResp.Status
	}

	return extractResp, nil
}

// GetExtractResult retrieves the extraction result
func (c *ExtractorClient) GetExtractResult(ctx context.Context, documentID string) (*ExtractResponse, error) {
	// Create a new HTTP request to the result endpoint
	url := fmt.Sprintf("%s/result/%s", c.BaseURL, documentID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Send the request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Check for error status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("extractor service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var resultResp struct {
		DocumentID string `json:"document_id"`
		Text       string `json:"text"`
		Status     string `json:"status"`
	}
	if err := json.Unmarshal(respBody, &resultResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// Map to our internal format
	extractResp := &ExtractResponse{
		Status: "COMPLETE",
		Text:   resultResp.Text,
	}

	return extractResp, nil
}
