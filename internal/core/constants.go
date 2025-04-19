package core

// MaxFileSize is the maximum file size for uploads (370 KB)
const MaxFileSize = 370 * 1024

// DocumentStatus represents the status of document processing
type DocumentStatus string

const (
	DocumentStatusPending    DocumentStatus = "PENDING"
	DocumentStatusProcessing DocumentStatus = "PROCESSING"
	DocumentStatusExtracted  DocumentStatus = "EXTRACTED"
	DocumentStatusSummarized DocumentStatus = "SUMMARIZED"
	DocumentStatusError      DocumentStatus = "ERROR"
)

// External API Status values
const (
	ExternalStatusOK         = "OK"
	ExternalStatusProcessing = "PROCESSING"
	ExternalStatusComplete   = "COMPLETE"
	ExternalStatusError      = "ERROR"
)
