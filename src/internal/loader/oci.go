package loader

import (
	"compress/gzip"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/jackc/pgx/v5"
	"github.com/joho/godotenv"
	"oci-costing/internal/chsink"
	"oci-costing/internal/config"
	"oci-costing/internal/output"
)

var ociHeaderToColumn = map[string]string{
	"lineItem/referenceNo":        "lineitem_referenceno",
	"lineItem/tenantId":           "lineitem_tenantid",
	"lineItem/intervalUsageStart": "lineitem_intervalusagestart",
	"lineItem/intervalUsageEnd":   "lineitem_intervalusageend",
	"product/service":             "product_service",
	"product/compartmentId":       "product_compartmentid",
	"product/compartmentName":     "product_compartmentname",
	"product/region":              "product_region",
	"product/availabilityDomain":  "product_availabilitydomain",
	"product/resourceId":          "product_resourceid",
	"usage/billedQuantity":        "usage_billedquantity",
	"usage/billedQuantityOverage": "usage_billedquantityoverage",
	"cost/subscriptionId":         "cost_subscriptionid",
	"cost/productSku":             "cost_productsku",
	"product/Description":         "product_description",
	"cost/unitPrice":              "cost_unitprice",
	"cost/unitPriceOverage":       "cost_unitpriceoverage",
	"cost/myCost":                 "cost_mycost",
	"cost/myCostOverage":          "cost_mycostoverage",
	"cost/currencyCode":           "cost_currencycode",
	"cost/billingUnitReadable":    "cost_billingunitreadable",
	"cost/skuUnitDescription":     "cost_skuunitdescription",
	"cost/overageFlag":            "cost_overageflag",
	"lineItem/isCorrection":       "lineitem_iscorrection",
	"lineItem/backreferenceNo":    "lineitem_backreferenceno",
	"cost/attributedCost":         "cost_attributedcost",
	"usage/attributedUsage":       "usage_attributedusage",
}

var ociNumericColumns = map[string]bool{
	"usage_billedquantity":        true,
	"usage_billedquantityoverage": true,
	"cost_unitprice":              true,
	"cost_unitpriceoverage":       true,
	"cost_mycost":                 true,
	"cost_mycostoverage":          true,
	"cost_attributedcost":         true,
	"usage_attributedusage":       true,
}

var ociTimestampColumns = map[string]bool{
	"lineitem_intervalusagestart": true,
	"lineitem_intervalusageend":   true,
}

const ociPerFileTimeout = 30 * time.Minute

func OCICostMain(target string) {
	_ = godotenv.Load()

	writePG, writeCH, err := config.SinkFlags()
	if err != nil {
		log.Fatalf("Sink config: %v", err)
	}

	var pgConn *pgx.Conn
	if writePG {
		cfg, err := config.BuildConnConfig()
		if err != nil {
			log.Fatalf("Config: %v", err)
		}
		connCtx, connCancel := context.WithTimeout(context.Background(), time.Minute)
		pgConn, err = pgx.ConnectConfig(connCtx, cfg)
		connCancel()
		if err != nil {
			log.Fatalf("Connect failed: %v", err)
		}
		defer pgConn.Close(context.Background())
		log.Printf("Connected to Postgres")
	}

	var chConn driver.Conn
	if writeCH {
		connCtx, connCancel := context.WithTimeout(context.Background(), time.Minute)
		chConn, err = chsink.Open(connCtx)
		connCancel()
		if err != nil {
			log.Fatalf("ClickHouse connect failed: %v", err)
		}
		defer chConn.Close()
		log.Printf("Connected to ClickHouse")
	}

	info, err := os.Stat(target)
	if err != nil {
		log.Fatalf("Cannot access %s: %v", target, err)
	}

	var files []string
	if info.IsDir() {
		err := filepath.WalkDir(target, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() && d.Name() == "archive" {
				return filepath.SkipDir
			}
			if !d.IsDir() && strings.HasSuffix(d.Name(), ".csv.gz") {
				files = append(files, path)
			}
			return nil
		})
		if err != nil {
			log.Fatalf("Walk folder: %v", err)
		}
		if len(files) == 0 {
			log.Fatalf("No .csv.gz files found in %s", target)
		}
	} else {
		files = []string{target}
	}

	log.Printf("Found %d file(s) to process", len(files))

	results := make([]output.FileResult, 0, len(files))
	failures := 0

	for _, filePath := range files {
		filename := filepath.Base(filePath)
		dateGroup := peekCostDate(filePath)

		fileCtx, cancel := context.WithTimeout(context.Background(), ociPerFileTimeout)

		// Per-sink presence check (only enabled sinks are consulted).
		pgHas, chHas := false, false
		var checkErr error
		if writePG {
			pgHas, checkErr = ociIsAlreadyLoaded(fileCtx, pgConn, filename)
		}
		if checkErr == nil && writeCH {
			chHas, checkErr = chsink.OCIIsAlreadyLoaded(fileCtx, chConn, filename)
		}
		if checkErr != nil {
			cancel()
			log.Printf("FAIL %s: check existing: %v", filename, checkErr)
			results = append(results, output.FileResult{Path: filePath, Status: "FAIL", Group: dateGroup})
			failures++
			continue
		}

		// All enabled sinks already have it -> skip + archive.
		if (!writePG || pgHas) && (!writeCH || chHas) {
			cancel()
			results = append(results, output.FileResult{Path: filePath, Status: "SKIP", Group: dateGroup})
			if err := ArchiveFile(filePath, target); err != nil {
				log.Printf("WARN: archive skip %s: %v", filename, err)
			}
			continue
		}

		// Load into each enabled sink lacking it, ClickHouse first then Postgres.
		// Any enabled-sink failure aborts the remaining loads (fail-soft, no archive).
		rows := 0
		var loadErr error
		if writeCH && !chHas {
			if n, err := chsink.OCILoadFile(fileCtx, chConn, filePath, filename); err != nil {
				loadErr = fmt.Errorf("clickhouse: %w", err)
			} else {
				rows = n
			}
		}
		if loadErr == nil && writePG && !pgHas {
			if n, err := ociLoadFile(fileCtx, pgConn, filePath, filename); err != nil {
				loadErr = fmt.Errorf("postgres: %w", err)
			} else {
				rows = n
			}
		}
		cancel()
		if loadErr != nil {
			log.Printf("FAIL %s: %v", filename, loadErr)
			results = append(results, output.FileResult{Path: filePath, Status: "FAIL", Group: dateGroup})
			failures++
			continue
		}

		results = append(results, output.FileResult{Path: filePath, Status: "DONE", Rows: rows, Group: dateGroup})
		if err := ArchiveFile(filePath, target); err != nil {
			log.Printf("WARN: archive done %s: %v", filename, err)
		}
	}

	output.PrintTree(target, results)
	if failures > 0 {
		os.Exit(2)
	}
}

func ociIsAlreadyLoaded(ctx context.Context, conn *pgx.Conn, filename string) (bool, error) {
	var exists bool
	err := conn.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM oci_cost_report WHERE source_filename = $1)",
		filename,
	).Scan(&exists)
	return exists, err
}

func ociLoadFile(ctx context.Context, conn *pgx.Conn, filePath, filename string) (int, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return 0, fmt.Errorf("open: %w", err)
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return 0, fmt.Errorf("gzip: %w", err)
	}
	defer gz.Close()

	reader := csv.NewReader(gz)
	reader.Comma = ','
	reader.LazyQuotes = true

	headers, err := reader.Read()
	if err != nil {
		return 0, fmt.Errorf("read headers: %w", err)
	}

	type colInfo struct {
		csvIndex int
		dbCol    string
	}
	var fixedCols []colInfo
	var tagCols []struct {
		csvIndex int
		tagName  string
	}

	for i, h := range headers {
		h = strings.TrimSpace(h)
		if strings.HasPrefix(h, "tags/") {
			tagName := strings.TrimPrefix(h, "tags/")
			tagCols = append(tagCols, struct {
				csvIndex int
				tagName  string
			}{i, tagName})
		} else if dbCol, ok := ociHeaderToColumn[h]; ok {
			fixedCols = append(fixedCols, colInfo{i, dbCol})
		} else {
			return 0, fmt.Errorf("unknown CSV header: %q", h)
		}
	}

	dbColumns := make([]string, 0, len(fixedCols)+2)
	for _, c := range fixedCols {
		dbColumns = append(dbColumns, c.dbCol)
	}
	dbColumns = append(dbColumns, "tags", "source_filename")

	log.Printf("  %s: %d fixed cols, %d tag cols, loading...", filename, len(fixedCols), len(tagCols))

	tx, err := conn.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	rows := make([][]any, 0, 10000)
	csvRows := 0
	dbRows := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, fmt.Errorf("row %d: %w", csvRows+1, err)
		}
		csvRows++

		row := make([]any, len(fixedCols)+2)

		for ri, c := range fixedCols {
			val := strings.TrimSpace(record[c.csvIndex])
			if val == "" {
				row[ri] = nil
				continue
			}
			switch {
			case ociNumericColumns[c.dbCol]:
				n, err := strconv.ParseFloat(val, 64)
				if err != nil {
					return 0, fmt.Errorf("row %d col %s: bad numeric %q: %w", csvRows, c.dbCol, val, err)
				}
				row[ri] = n
			case ociTimestampColumns[c.dbCol]:
				t, err := ParseTimestamp(val)
				if err != nil {
					return 0, fmt.Errorf("row %d col %s: bad timestamp %q: %w", csvRows, c.dbCol, val, err)
				}
				row[ri] = t
			default:
				row[ri] = val
			}
		}

		tags := make(map[string]string)
		for _, tc := range tagCols {
			val := strings.TrimSpace(record[tc.csvIndex])
			if val != "" {
				tags[tc.tagName] = val
			}
		}
		if len(tags) > 0 {
			b, _ := json.Marshal(tags)
			row[len(fixedCols)] = string(b)
		} else {
			row[len(fixedCols)] = nil
		}

		row[len(fixedCols)+1] = filename
		rows = append(rows, row)

		if len(rows) >= 10000 {
			n, err := ociCopyRows(ctx, tx, dbColumns, rows)
			if err != nil {
				return 0, fmt.Errorf("COPY at row %d: %w", csvRows, err)
			}
			dbRows += int(n)
			rows = rows[:0]
			log.Printf("  %s: read %d csv rows, loaded %d to db...", filename, csvRows, dbRows)
		}
	}

	if len(rows) > 0 {
		n, err := ociCopyRows(ctx, tx, dbColumns, rows)
		if err != nil {
			return 0, fmt.Errorf("COPY final: %w", err)
		}
		dbRows += int(n)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit: %w", err)
	}

	log.Printf("  %s: complete — %d rows in csv, %d rows loaded to db", filename, csvRows, dbRows)
	return dbRows, nil
}

func ociCopyRows(ctx context.Context, tx pgx.Tx, columns []string, rows [][]any) (int64, error) {
	return tx.CopyFrom(
		ctx,
		pgx.Identifier{"oci_cost_report"},
		columns,
		pgx.CopyFromRows(rows),
	)
}

func peekCostDate(filePath string) string {
	f, err := os.Open(filePath)
	if err != nil {
		return "unknown"
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return "unknown"
	}
	defer gz.Close()

	reader := csv.NewReader(gz)
	reader.LazyQuotes = true

	headers, err := reader.Read()
	if err != nil {
		return "unknown"
	}

	dateIdx := -1
	for i, h := range headers {
		if strings.TrimSpace(h) == "lineItem/intervalUsageStart" {
			dateIdx = i
			break
		}
	}
	if dateIdx < 0 {
		return "unknown"
	}

	row, err := reader.Read()
	if err != nil || dateIdx >= len(row) {
		return "unknown"
	}

	t, err := ParseTimestamp(strings.TrimSpace(row[dateIdx]))
	if err != nil {
		return "unknown"
	}
	return t.Format("2006/01/02")
}
