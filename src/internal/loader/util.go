package loader

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

func ArchiveFile(filePath, sourceDir string) error {
	archiveDir := filepath.Join(sourceDir, "archive")
	if err := os.MkdirAll(archiveDir, 0755); err != nil {
		return fmt.Errorf("create archive dir: %w", err)
	}
	dest := filepath.Join(archiveDir, filepath.Base(filePath))
	if err := os.Rename(filePath, dest); err != nil {
		return fmt.Errorf("move to archive: %w", err)
	}
	return nil
}

func ParseTimestamp(val string) (time.Time, error) {
	formats := []string{
		time.RFC3339,
		"2006-01-02T15:04:05Z",
		"2006-01-02T15:04Z",
		"2006-01-02 15:04:05",
		"2006-01-02",
	}
	for _, f := range formats {
		if t, err := time.Parse(f, val); err == nil {
			return t, nil
		}
	}
	return time.Time{}, fmt.Errorf("unrecognized timestamp format: %s", val)
}

// JSONOrNil returns val if it parses as valid JSON, else nil.
// For jsonb columns: malformed input becomes NULL rather than a JSON-encoded
// scalar (which would corrupt structure, e.g. "k=v" -> "\"k=v\"").
func JSONOrNil(val string) any {
	if val == "" {
		return nil
	}
	if json.Valid([]byte(val)) {
		return val
	}
	return nil
}
