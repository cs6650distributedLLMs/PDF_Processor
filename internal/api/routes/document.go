package routes

import (
	"github.com/gin-gonic/gin"

	"tldr/internal/api/handlers"
)

// SetupRoutes sets up the document routes
func SetupRoutes(router *gin.Engine) {
	v1 := router.Group("/v1/documents")
	{
		// Upload a new PDF
		v1.POST("/", handlers.UploadController)

		// Get document status
		v1.GET("/:id/status", handlers.StatusController)

		// Get extracted text
		v1.GET("/:id/text", handlers.GetExtractedTextController)

		// Download the summarized text
		v1.GET("/:id/download", handlers.DownloadController)

		// Get document metadata
		v1.GET("/:id", handlers.GetController)

		// Request to summarize a PDF
		v1.POST("/:id/summarize", handlers.SummarizeController)

		// Delete a document
		v1.DELETE("/:id", handlers.DeleteController)

		// List all document
		v1.GET("/", handlers.ListController)
	}
}
