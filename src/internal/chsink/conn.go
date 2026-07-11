package chsink

import (
	"context"
	"fmt"
	"os"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
)

// Open dials ClickHouse using the CLICKHOUSE_URL DSN. ParseDSN handles both
// the non-TLS native port (9000, dev) and the secure port (9440); the target
// database (`oci-finops`) comes from the DSN, so all table names stay unqualified.
func Open(ctx context.Context) (driver.Conn, error) {
	dsn := os.Getenv("CLICKHOUSE_URL")
	if dsn == "" {
		return nil, fmt.Errorf("CLICKHOUSE_URL not set")
	}

	opt, err := clickhouse.ParseDSN(dsn)
	if err != nil {
		return nil, fmt.Errorf("parse CLICKHOUSE_URL: %w", err)
	}

	conn, err := clickhouse.Open(opt)
	if err != nil {
		return nil, fmt.Errorf("open clickhouse: %w", err)
	}
	if err := conn.Ping(ctx); err != nil {
		return nil, fmt.Errorf("ping clickhouse: %w", err)
	}
	return conn, nil
}
