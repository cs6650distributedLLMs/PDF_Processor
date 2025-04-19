package clients

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
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

// ExtractRequest represents a request to extract text from a PDF
type ExtractRequest struct {
	DocumentID string `json:"documentId"`
	Base64     string `json:"base64"`
}

// ExtractResponse represents a response from the PDF extractor service
type ExtractResponse struct {
	Status string `json:"status"`
	Result string `json:"result,omitempty"`
}

// ExtractText sends a request to extract text from a PDF
func (c *ExtractorClient) ExtractText(ctx context.Context, documentID string, pdfData []byte) (*ExtractResponse, error) {
	// Create the request to the PDF extractor service
	url := c.BaseURL

	// Convert PDF data to base64
	base64Data := base64.StdEncoding.EncodeToString(pdfData)

	// Prepare the request payload
	reqBody, err := json.Marshal(ExtractRequest{
		DocumentID: documentID,
		Base64:     base64Data,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create a new HTTP request
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

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
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return nil, fmt.Errorf("extractor service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var extractResp ExtractResponse
	if err := json.Unmarshal(respBody, &extractResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &extractResp, nil
}

// GetExtractStatus polls the Extract endpoint to check the status
func (c *ExtractorClient) GetExtractStatus(ctx context.Context, documentID string) (*ExtractResponse, error) {
	// For the new API, we need to call the Extract endpoint with just the documentId
	url := c.BaseURL

	// Prepare an empty request with just the documentId (no base64 data)
	reqBody, err := json.Marshal(map[string]string{
		"documentId": documentID,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Create a new HTTP request
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

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

	return &extractResp, nil
}
