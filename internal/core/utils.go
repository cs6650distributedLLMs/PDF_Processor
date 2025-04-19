package core

import (
	"path/filepath"
)

// ConvertBytesToKb converts bytes to kilobytes
func ConvertBytesToKb(bytes int64) float64 {
	return float64(bytes) / 1024
}

// GetBaseName returns the base name of a file without the extension
func GetBaseName(fileName string) string {
	ext := filepath.Ext(fileName)
	return fileName[:len(fileName)-len(ext)]
}
