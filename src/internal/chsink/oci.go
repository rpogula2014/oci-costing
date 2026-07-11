package chsink

import (
	"compress/gzip"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/shopspring/decimal"
)

// ociHeaderToColumn maps OCI cost-report CSV headers to CH column names.
// Copied verbatim from internal/loader/oci.go.
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

// Decimal columns — Nullable(Decimal(20,10)) in CH; empty cell -> NULL.
var ociDecimalColumns = map[string]bool{
	"usage_billedquantity":        true,
	"usage_billedquantityoverage": true,
	"cost_unitprice":              true,
	"cost_unitpriceoverage":       true,
	"cost_mycost":                 true,
	"cost_mycostoverage":          true,
	"cost_attributedcost":         true,
	"usage_attributedusage":       true,
}

// Timestamp columns — DateTime64(3). intervalusagestart is non-Nullable
// (partition/order key); intervalusageend is Nullable.
var ociTimestampColumns = map[string]bool{
	"lineitem_intervalusagestart": true,
	"lineitem_intervalusageend":   true,
}
var ociNonNullTimestampColumns = map[string]bool{
	"lineitem_intervalusagestart": true,
}

// OCIIsAlreadyLoaded reports whether any row for this filename already exists.
func OCIIsAlreadyLoaded(ctx context.Context, conn driver.Conn, filename string) (bool, error) {
	var n uint64
	err := conn.QueryRow(ctx,
		"SELECT count() FROM oci_cost_report WHERE source_filename = ?",
		filename,
	).Scan(&n)
	return n > 0, err
}

// OCILoadFile streams a gzipped OCI cost report into oci_cost_report via the
// batch API, flushing every 10,000 rows.
func OCILoadFile(ctx context.Context, conn driver.Conn, filePath, filename string) (int, error) {
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
			tagCols = append(tagCols, struct {
				csvIndex int
				tagName  string
			}{i, strings.TrimPrefix(h, "tags/")})
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

	insertSQL := "INSERT INTO oci_cost_report (" + strings.Join(dbColumns, ", ") + ")"
	batch, err := conn.PrepareBatch(ctx, insertSQL)
	if err != nil {
		return 0, fmt.Errorf("prepare batch: %w", err)
	}

	buffered := 0
	totalRows := 0
	sentOnce := false

	fail := func(cause error) (int, error) {
		if sentOnce {
			if derr := conn.Exec(ctx, "DELETE FROM oci_cost_report WHERE source_filename = ?", filename); derr != nil {
				log.Printf("  %s: cleanup DELETE failed: %v", filename, derr)
			} else {
				log.Printf("  %s: rolled back %d partial rows via lightweight DELETE", filename, totalRows)
			}
		}
		return 0, cause
	}

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fail(fmt.Errorf("row %d: %w", totalRows+buffered+1, err))
		}
		rowNum := totalRows + buffered + 1

		row := make([]any, 0, len(fixedCols)+2)
		for _, c := range fixedCols {
			val := strings.TrimSpace(record[c.csvIndex])
			switch {
			case ociDecimalColumns[c.dbCol]:
				if val == "" {
					row = append(row, (*decimal.Decimal)(nil))
					break
				}
				d, err := decimal.NewFromString(val)
				if err != nil {
					return fail(fmt.Errorf("row %d col %s: bad numeric %q: %w", rowNum, c.dbCol, val, err))
				}
				row = append(row, &d)
			case ociTimestampColumns[c.dbCol]:
				if val == "" {
					if ociNonNullTimestampColumns[c.dbCol] {
						row = append(row, time.Time{}) // non-Nullable; empty not expected
					} else {
						row = append(row, (*time.Time)(nil))
					}
					break
				}
				t, err := parseTimestamp(val)
				if err != nil {
					return fail(fmt.Errorf("row %d col %s: bad timestamp %q: %w", rowNum, c.dbCol, val, err))
				}
				row = append(row, t)
			default:
				row = append(row, val) // String column; "" stays ""
			}
		}

		// tags: all tags/* columns rolled into a flat string map; skip empty cells.
		tags := make(map[string]string)
		for _, tc := range tagCols {
			val := strings.TrimSpace(record[tc.csvIndex])
			if val != "" {
				tags[tc.tagName] = val
			}
		}
		row = append(row, tags)
		row = append(row, filename)

		if err := batch.Append(row...); err != nil {
			return fail(fmt.Errorf("append row %d: %w", rowNum, err))
		}
		buffered++

		if buffered >= 10000 {
			if err := batch.Send(); err != nil {
				return fail(fmt.Errorf("batch send at row %d: %w", rowNum, err))
			}
			sentOnce = true
			totalRows += buffered
			buffered = 0
			log.Printf("  %s: %d rows so far...", filename, totalRows)
			if batch, err = conn.PrepareBatch(ctx, insertSQL); err != nil {
				return fail(fmt.Errorf("re-prepare batch: %w", err))
			}
		}
	}

	if err := batch.Send(); err != nil {
		return fail(fmt.Errorf("batch send final: %w", err))
	}
	totalRows += buffered

	log.Printf("  %s: complete — %d rows loaded to clickhouse", filename, totalRows)
	return totalRows, nil
}
