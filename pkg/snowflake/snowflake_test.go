package snowflake

import (
	"sync"
	"testing"
	"time"
)

func TestNodeIDRange(t *testing.T) {
	// Test invalid node IDs
	invalidIDs := []int64{-1, nodeMax + 1, 1500}

	for _, id := range invalidIDs {
		node, err := NewNode(id)
		if err == nil {
			t.Errorf("Expected error when creating node with invalid ID %d", id)
		}
		if node != nil {
			t.Errorf("Expected nil node when creating with invalid ID %d", id)
		}
	}

	// Test valid node IDs
	validIDs := []int64{0, 1, 100, nodeMax}

	for _, id := range validIDs {
		node, err := NewNode(id)
		if err != nil {
			t.Errorf("Unexpected error when creating node with valid ID %d: %v", id, err)
		}
		if node == nil {
			t.Errorf("Expected non-nil node when creating with valid ID %d", id)
		}
	}
}

func TestGenerateID(t *testing.T) {
	node, err := NewNode(1)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	id := node.Generate()
	if id <= 0 {
		t.Errorf("Expected positive ID, got %d", id)
	}
}

func TestIDUniqueness(t *testing.T) {
	node, err := NewNode(1)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	// Generate a bunch of IDs and make sure they're all different
	idMap := make(map[ID]bool)
	iterations := 100000 // Adjust based on your machine's performance

	for i := 0; i < iterations; i++ {
		id := node.Generate()
		if idMap[id] {
			t.Fatalf("Duplicate ID generated: %d", id)
		}
		idMap[id] = true
	}
}

func TestIDStructure(t *testing.T) {
	node, err := NewNode(5)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	id := node.Generate()
	idInt := int64(id)

	// Extract the node ID from the generated ID
	extractedNode := (idInt >> nodeShift) & nodeMax

	if extractedNode != 5 {
		t.Errorf("Expected node ID 5, got %d", extractedNode)
	}

	// Ensure sequence starts at 0
	sequence := idInt & sequenceMask
	if sequence != 0 {
		t.Errorf("Expected sequence 0 on first generation, got %d", sequence)
	}

	// Get second ID and ensure sequence increments
	id2 := node.Generate()
	id2Int := int64(id2)
	sequence2 := id2Int & sequenceMask
	if sequence2 != 1 {
		t.Errorf("Expected sequence 1 on second generation, got %d", sequence2)
	}
}

func TestIDTimestamp(t *testing.T) {
	node, err := NewNode(1)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	now := time.Now().UnixMilli()
	id := node.Generate()
	idInt := int64(id)

	// Extract timestamp
	timestamp := (idInt >> timestampShift) + epoch

	// The extracted timestamp should be very close to 'now'
	diff := timestamp - now
	if diff < -5 || diff > 5 {
		t.Errorf("Timestamp in ID (%d) differs too much from current time (%d), diff: %d", timestamp, now, diff)
	}
}

func TestConcurrentGeneration(t *testing.T) {
	node, err := NewNode(1)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	var wg sync.WaitGroup
	idMap := sync.Map{}
	workers := 10
	idsPerWorker := 1000

	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := 0; i < idsPerWorker; i++ {
				id := node.Generate()
				if _, loaded := idMap.LoadOrStore(id, true); loaded {
					t.Errorf("Duplicate ID generated: %d", id)
				}
			}
		}()
	}

	wg.Wait()
}

func TestSequenceOverflow(t *testing.T) {
	node := &Node{
		node:     1,
		sequence: sequenceMask - 1,
		time:     time.Now().UnixMilli(),
	}

	// First call should increment to the max sequence
	id1 := node.Generate()
	sequence1 := int64(id1) & sequenceMask

	// Second call should overflow and reset to 0
	id2 := node.Generate()
	sequence2 := int64(id2) & sequenceMask

	if sequence1 != sequenceMask {
		t.Errorf("Expected max sequence %d, got %d", sequenceMask, sequence1)
	}

	if sequence2 != 0 {
		t.Errorf("Expected sequence 0 after overflow, got %d", sequence2)
	}
}

func TestIDString(t *testing.T) {
	node, err := NewNode(1)
	if err != nil {
		t.Fatalf("Error creating Node: %v", err)
	}

	id := node.Generate()
	idStr := id.String()

	// Ensure the string representation is non-empty
	if idStr == "" {
		t.Error("Expected non-empty string representation of ID")
	}

	// Ensure the string is a valid number
	for _, ch := range idStr {
		if ch < '0' || ch > '9' {
			t.Errorf("Expected string to contain only digits, found: %c", ch)
		}
	}
}

func BenchmarkIDGeneration(b *testing.B) {
	node, _ := NewNode(1)
	b.ResetTimer()

	for i := 0; i < b.N; i++ {
		_ = node.Generate()
	}
}

func BenchmarkParallelIDGeneration(b *testing.B) {
	node, _ := NewNode(1)
	b.ResetTimer()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = node.Generate()
		}
	})
}
