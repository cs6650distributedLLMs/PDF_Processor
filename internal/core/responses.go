package core

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// SendOkResponse sends a 200 OK response with the given data
func SendOkResponse(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, data)
}

// SendAcceptedResponse sends a 202 Accepted response with the given data
func SendAcceptedResponse(c *gin.Context, data interface{}) {
	c.JSON(http.StatusAccepted, data)
}

// SendNoContentResponse sends a 204 No Content response
func SendNoContentResponse(c *gin.Context) {
	c.Status(http.StatusNoContent)
}

// SendBadRequestResponse sends a 400 Bad Request response with an optional error message
func SendBadRequestResponse(c *gin.Context, message string) {
	if message == "" {
		message = "Bad request"
	}
	c.JSON(http.StatusBadRequest, gin.H{"message": message})
}

// SendNotFoundResponse sends a 404 Not Found response
func SendNotFoundResponse(c *gin.Context) {
	c.JSON(http.StatusNotFound, gin.H{"message": "Not found"})
}

// SendResponse sends a response with the given status code and message
func SendResponse(c *gin.Context, status int, message string) {
	c.JSON(status, gin.H{"message": message})
}

// SendErrorResponse sends a 500 Internal Server Error response with an optional error message
func SendErrorResponse(c *gin.Context, err error) {
	status := http.StatusInternalServerError
	message := "Internal server error"
	if err != nil {
		message = err.Error()
	}
	c.JSON(status, gin.H{"message": message})
}
