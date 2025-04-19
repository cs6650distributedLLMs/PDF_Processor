package snowflake

import (
	"fmt"
	"strconv"
	"sync"
	"time"
)

/*
Snowflake ID Format:

The ID is composed of:

+-------------+------------+------------+
| Timestamp   | Node ID    | Sequence   |
| 41 bits     | 10 bits    | 12 bits    |
+-------------+------------+------------+

1. Timestamp: 41 bits (milliseconds since 2020-01-01 00:00:00 UTC)
   - Gives us ~69 years of IDs before overflow

2. Node ID: 10 bits
   - Allows for 1024 different nodes/machines (0-1023)

3. Sequence: 12 bits
   - Allows for 4096 IDs per millisecond per node (0-4095)

Total: 63 bits
We use 63 bits instead of 64 to fit within a signed int64

                       Snowflake ID Structure
+-------------------------------------------------------------------------+
| 41 bits                | 10 bits       | 12 bits                        |
| Timestamp (ms)         | Node ID       | Sequence                       |
+-------------------------+---------------+--------------------------------+
| 0000000000000000000000 | 0000000000    | 000000000000                   |
+-------------------------------------------------------------------------+
*/

const (
	epoch                = int64(1577836800000) // 2020-01-01 00:00:00 UTC
	nodeBits       uint8 = 10
	sequenceBits   uint8 = 12
	nodeMax        int64 = -1 ^ (-1 << nodeBits)
	sequenceMask   int64 = -1 ^ (-1 << sequenceBits)
	nodeShift            = sequenceBits
	timestampShift       = sequenceBits + nodeBits
)

// Node is a snowflake ID generator
type Node struct {
	mu       sync.Mutex
	time     int64
	node     int64
	sequence int64
}

type ID int64

// NewNode creates a new snowflake node that can be used to generate IDs
func NewNode(node int64) (*Node, error) {
	if node < 0 || node > nodeMax {
		return nil, fmt.Errorf("node number must be between 0 and %d", nodeMax)
	}
	return &Node{
		node: node,
	}, nil
}

// Generate creates a new snowflake ID
func (n *Node) Generate() ID {
	n.mu.Lock()
	defer n.mu.Unlock()

	now := time.Now().UnixMilli()

	if now == n.time {
		n.sequence = (n.sequence + 1) & sequenceMask
		if n.sequence == 0 {
			for now <= n.time {
				now = time.Now().UnixMilli()
			}
		}
	} else {
		n.sequence = 0
	}

	n.time = now

	id := ID(((now - epoch) << timestampShift) |
		(n.node << nodeShift) |
		n.sequence)

	return id
}

func (id ID) String() string {
	return strconv.FormatInt(int64(id), 10)
}
