package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// SummarizerClient is the client for the text summarizer service
type SummarizerClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

// NewSummarizerClient creates a new text summarizer client
func NewSummarizerClient() *SummarizerClient {
	return &SummarizerClient{
		BaseURL: os.Getenv("TEXT_SUMMARIZER_SERVICE_URL"),
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// SummarizeRequest represents a request to summarize text
type SummarizeRequest struct {
	DocumentID string `json:"documentId"`
	Content    string `json:"content"`
}

// SummarizeResponse represents a response from the text summarizer service
type SummarizeResponse struct {
	Status string `json:"status"`
	Result string `json:"result,omitempty"`
}

// SummarizeText sends a request to summarize text
func (c *SummarizerClient) SummarizeText(ctx context.Context, documentID, text string) (*SummarizeResponse, error) {
	// Create the request to the text summarizer service
	url := c.BaseURL

	// Prepare the request payload
	reqBody, err := json.Marshal(SummarizeRequest{
		DocumentID: documentID,
		Content:    text,
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
		return nil, fmt.Errorf("summarizer service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var summarizeResp SummarizeResponse
	if err := json.Unmarshal(respBody, &summarizeResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &summarizeResp, nil
}

// GetSummaryStatus polls the Summarize endpoint to check the status
func (c *SummarizerClient) GetSummaryStatus(ctx context.Context, documentID string) (*SummarizeResponse, error) {
	// For the new API, we need to call the Summarize endpoint with just the documentId
	url := c.BaseURL

	// Prepare an empty request with just the documentId
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
		return nil, fmt.Errorf("summarizer service returned status %d: %s", resp.StatusCode, respBody)
	}

	// Parse the response
	var summarizeResp SummarizeResponse
	if err := json.Unmarshal(respBody, &summarizeResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &summarizeResp, nil
}

// GetSummary is now just an alias for GetSummaryStatus since the result is directly in the response
func (c *SummarizerClient) GetSummary(ctx context.Context, documentID string) (string, error) {
	resp, err := c.GetSummaryStatus(ctx, documentID)
	if err != nil {
		return "", err
	}

	if resp.Status != "COMPLETE" {
		return "", fmt.Errorf("summary not ready yet, current status: %s", resp.Status)
	}

	return resp.Result, nil
}
