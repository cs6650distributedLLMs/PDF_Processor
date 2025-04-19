package core

import (
	"log"
	"os"
	"strconv"
	"sync"

	"tldr/pkg/snowflake"
)

var (
	snowflakeNode *snowflake.Node
	once          sync.Once
)

// InitSnowflake initializes the snowflake node with a node ID
func InitSnowflake() {
	once.Do(func() {
		// Get node ID from environment
		nodeIDStr := os.Getenv("NODE_ID")
		if nodeIDStr == "" {
			log.Fatal("NODE_ID environment variable is required but not set. Please set a unique node ID (0-1023)")
		}

		nodeID, err := strconv.ParseInt(nodeIDStr, 10, 64)
		if err != nil {
			log.Fatalf("Invalid NODE_ID environment variable: %v. Must be a number between 0-1023", err)
		}

		// Validate node ID range
		if nodeID < 0 || nodeID > 1023 {
			log.Fatalf("NODE_ID must be between 0 and 1023, got %d", nodeID)
		}

		snowflakeNode, err = snowflake.NewNode(nodeID)
		if err != nil {
			log.Fatalf("Failed to initialize snowflake node: %v", err)
		}

		log.Printf("Snowflake ID generator initialized with node ID: %d", nodeID)
	})
}

// GenerateID generates a new snowflake ID
func GenerateID() snowflake.ID {
	if snowflakeNode == nil {
		InitSnowflake()
	}
	return snowflakeNode.Generate()
}

// GenerateIDString generates a new snowflake ID as a string
func GenerateIDString() string {
	return GenerateID().String()
}
