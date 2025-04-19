package models

import (
	"time"

	"tldr/internal/core"
)

// Document represents a document item stored in the database
type Document struct {
	DocumentID string              `json:"documentId"`
	Size       int64               `json:"size"`
	Name       string              `json:"name"`
	MimeType   string              `json:"mimetype"`
	Status     core.DocumentStatus `json:"status"`
	Content    []byte              `json:"-"` // PDF content, not included in JSON responses
	CreatedAt  time.Time           `json:"createdAt,omitempty"`
	UpdatedAt  time.Time           `json:"updatedAt,omitempty"`
}

// DocumentUploadResult represents the result of a document upload
type DocumentUploadResult struct {
	DocumentID string `json:"documentId"`
}

// DocumentStatus represents the status of a document item
type DocumentStatus struct {
	Status core.DocumentStatus `json:"status"`
}

// DocumentListItem represents a document item in a list
type DocumentListItem struct {
	DocumentID string `json:"documentId"`
	Size       int64  `json:"size"`
	Name       string `json:"name"`
	MimeType   string `json:"mimetype"`
}

// ExtractedTextResponse represents the response for extracted text
type ExtractedTextResponse struct {
	DocumentID string `json:"documentId"`
	Text       string `json:"text"`
}
