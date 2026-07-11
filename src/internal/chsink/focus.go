package chsink

import (
	"compress/gzip"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/shopspring/decimal"
	"oci-costing/internal/config"
)

// focusHeaderToColumn maps FOCUS CSV headers to ClickHouse column names.
// Copied verbatim from internal/loader/focus.go so the two sinks stay in lockstep.
var focusHeaderToColumn = map[string]string{
	"AvailabilityZone":           "availabilityzone",
	"BilledCost":                 "billedcost",
	"BillingAccountId":           "billingaccountid",
	"BillingAccountName":         "billingaccountname",
	"BillingCurrency":            "billingcurrency",
	"BillingPeriodEnd":           "billingperiodend",
	"BillingPeriodStart":         "billingperiodstart",
	"ChargeCategory":             "chargecategory",
	"ChargeDescription":          "chargedescription",
	"ChargeFrequency":            "chargefrequency",
	"ChargePeriodEnd":            "chargeperiodend",
	"ChargePeriodStart":          "chargeperiodstart",
	"ChargeSubcategory":          "chargesubcategory",
	"CommitmentDiscountCategory": "commitmentdiscountcategory",
	"CommitmentDiscountId":       "commitmentdiscountid",
	"CommitmentDiscountName":     "commitmentdiscountname",
	"CommitmentDiscountType":     "commitmentdiscounttype",
	"EffectiveCost":              "effectivecost",
	"InvoiceIssuer":              "invoiceissuer",
	"ListCost":                   "listcost",
	"ListUnitPrice":              "listunitprice",
	"PricingCategory":            "pricingcategory",
	"PricingQuantity":            "pricingquantity",
	"PricingUnit":                "pricingunit",
	"Provider":                   "provider",
	"Publisher":                  "publisher",
	"Region":                     "region",
	"ResourceId":                 "resourceid",
	"ResourceName":               "resourcename",
	"ResourceType":               "resourcetype",
	"ServiceCategory":            "servicecategory",
	"ServiceName":                "servicename",
	"SkuId":                      "skuid",
	"SkuPriceId":                 "skupriceid",
	"SubAccountId":               "subaccountid",
	"SubAccountName":             "subaccountname",
	"Tags":                       "tags",
	"UsageQuantity":              "usagequantity",
	"UsageUnit":                  "usageunit",
	"oci_ReferenceNumber":        "oci_referencenumber",
	"oci_CompartmentId":          "oci_compartmentid",
	"oci_CompartmentName":        "oci_compartmentname",
	"oci_OverageFlag":            "oci_overageflag",
	"oci_UnitPriceOverage":       "oci_unitpriceoverage",
	"oci_BilledQuantityOverage":  "oci_billedquantityoverage",
	"oci_CostOverage":            "oci_costoverage",
	"oci_AttributedUsage":        "oci_attributedusage",
	"oci_AttributedCost":         "oci_attributedcost",
	"oci_BackReferenceNumber":    "oci_backreferencenumber",
}

// Decimal columns — Nullable(Decimal(20,10)) in CH; empty cell -> NULL.
var focusDecimalColumns = map[string]bool{
	"billedcost": true, "effectivecost": true, "listcost": true,
	"listunitprice": true, "pricingquantity": true, "usagequantity": true,
	"oci_unitpriceoverage": true, "oci_billedquantityoverage": true,
	"oci_costoverage": true, "oci_attributedusage": true, "oci_attributedcost": true,
}

// Timestamp columns — DateTime64(3) in CH. billingperiodstart is non-Nullable
// (partition/order key, always present); the rest are Nullable.
var focusTimestampColumns = map[string]bool{
	"billingperiodstart": true, "billingperiodend": true,
	"chargeperiodstart": true, "chargeperiodend": true,
}
var focusNonNullTimestampColumns = map[string]bool{
	"billingperiodstart": true,
}

// FocusIsAlreadyLoaded reports whether any row for this filename already exists.
// Pre-insert dedup guard, mirroring the PG EXISTS check.
func FocusIsAlreadyLoaded(ctx context.Context, conn driver.Conn, filename string) (bool, error) {
	var n uint64
	err := conn.QueryRow(ctx,
		"SELECT count() FROM focus_data WHERE source_filename = ?",
		filename,
	).Scan(&n)
	return n > 0, err
}

// FocusLoadFile streams a gzipped FOCUS CSV into the focus_data table via the
// clickhouse-go batch API, flushing every 10,000 rows.
func FocusLoadFile(ctx context.Context, conn driver.Conn, filePath, filename string, tagsCfg *config.TagsConfig) (int, error) {
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

	// Build lookup of configured tag keys (tags/<key> -> db key).
	tagKeyMap := make(map[string]string)
	for _, t := range tagsCfg.Tags {
		tagKeyMap["tags/"+t.Key] = t.DBKey
	}

	// Classify headers: fixed columns, the Tags JSON column, and configured
	// tags/* extras. tags is always a CH column, so it's never a fixed col.
	type colInfo struct {
		csvIndex int
		dbCol    string
	}
	var fixedCols []colInfo
	tagsCsvIndex := -1
	tagCol := make(map[int]string) // csvIndex -> db tag key

	for i, h := range headers {
		h = strings.TrimSpace(h)
		if strings.HasPrefix(h, "tags/") {
			if dbKey, ok := tagKeyMap[h]; ok {
				tagCol[i] = dbKey
			}
			continue
		}
		dbCol, ok := focusHeaderToColumn[h]
		if !ok {
			return 0, fmt.Errorf("unknown CSV header: %q", h)
		}
		if dbCol == "tags" {
			tagsCsvIndex = i
			continue
		}
		fixedCols = append(fixedCols, colInfo{i, dbCol})
	}

	dbColumns := make([]string, 0, len(fixedCols)+2)
	for _, c := range fixedCols {
		dbColumns = append(dbColumns, c.dbCol)
	}
	dbColumns = append(dbColumns, "tags", "source_filename")

	log.Printf("  %s: %d fixed cols, %d tag cols, loading...", filename, len(fixedCols), len(tagCol))

	insertSQL := "INSERT INTO focus_data (" + strings.Join(dbColumns, ", ") + ")"
	batch, err := conn.PrepareBatch(ctx, insertSQL)
	if err != nil {
		return 0, fmt.Errorf("prepare batch: %w", err)
	}

	buffered := 0
	totalRows := 0
	sentOnce := false // once true, a mid-load failure leaves partial rows to clean up

	// fail deletes already-sent rows for this file, then wraps the cause.
	fail := func(cause error) (int, error) {
		if sentOnce {
			if derr := conn.Exec(ctx, "DELETE FROM focus_data WHERE source_filename = ?", filename); derr != nil {
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
			case focusDecimalColumns[c.dbCol]:
				if val == "" {
					row = append(row, (*decimal.Decimal)(nil))
					break
				}
				d, err := decimal.NewFromString(val)
				if err != nil {
					return fail(fmt.Errorf("row %d col %s: bad numeric %q: %w", rowNum, c.dbCol, val, err))
				}
				row = append(row, &d)
			case focusTimestampColumns[c.dbCol]:
				if val == "" {
					if focusNonNullTimestampColumns[c.dbCol] {
						row = append(row, time.Time{}) // non-Nullable; empty is not expected here
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

		row = append(row, buildFocusTags(record, tagsCsvIndex, tagCol, filename, rowNum))
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

// buildFocusTags flattens the Tags JSON cell (values coerced to strings) and
// merges configured tags/* extras — existing JSON keys win, matching the loader.
func buildFocusTags(record []string, tagsCsvIndex int, tagCol map[int]string, filename string, rowNum int) map[string]string {
	tags := make(map[string]string)

	if tagsCsvIndex >= 0 && tagsCsvIndex < len(record) {
		val := strings.TrimSpace(record[tagsCsvIndex])
		if val != "" {
			var parsed map[string]any
			if err := json.Unmarshal([]byte(val), &parsed); err == nil {
				for k, v := range parsed {
					if s, ok := v.(string); ok {
						tags[k] = s
					} else {
						tags[k] = fmt.Sprint(v) // non-string tag value, expected rare
					}
				}
			} else {
				// Malformed Tags JSON: drop it (loader stored NULL here).
				log.Printf("  %s: row %d: malformed Tags JSON, storing empty tags", filename, rowNum)
				return tags
			}
		}
	}

	// Merge configured extras without overwriting keys from the Tags JSON.
	for idx, dbKey := range tagCol {
		if idx >= len(record) {
			continue
		}
		v := strings.TrimSpace(record[idx])
		if v == "" {
			continue
		}
		if _, exists := tags[dbKey]; !exists {
			tags[dbKey] = v
		}
	}
	return tags
}
