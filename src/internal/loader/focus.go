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
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
	"oci-costing/internal/config"
)

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

var focusNumericColumns = map[string]bool{
	"billedcost": true, "effectivecost": true, "listcost": true,
	"listunitprice": true, "pricingquantity": true, "usagequantity": true,
	"oci_unitpriceoverage": true, "oci_billedquantityoverage": true,
	"oci_costoverage": true, "oci_attributedusage": true, "oci_attributedcost": true,
}

var focusTimestampColumns = map[string]bool{
	"billingperiodstart": true, "billingperiodend": true,
	"chargeperiodstart": true, "chargeperiodend": true,
}

func FocusIsAlreadyLoaded(ctx context.Context, conn *pgx.Conn, filename string) (bool, error) {
	var exists bool
	err := conn.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM focus_data_table WHERE source_filename = $1)",
		filename,
	).Scan(&exists)
	return exists, err
}

func FocusLoadFile(ctx context.Context, conn *pgx.Conn, filePath, filename string, tagsCfg *config.TagsConfig) (int, error) {
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

	// Build lookup of configured tag keys
	tagKeyMap := make(map[string]string)
	for _, t := range tagsCfg.Tags {
		tagKeyMap["tags/"+t.Key] = t.DBKey
	}

	colMap := make([]string, len(headers))
	skipCol := make([]bool, len(headers))
	tagCol := make(map[int]string)
	hasTagsColumn := false
	for i, h := range headers {
		h = strings.TrimSpace(h)
		if strings.HasPrefix(h, "tags/") {
			if dbKey, ok := tagKeyMap[h]; ok {
				tagCol[i] = dbKey
			}
			skipCol[i] = true
			continue
		}
		dbCol, ok := focusHeaderToColumn[h]
		if !ok {
			return 0, fmt.Errorf("unknown CSV header: %q", h)
		}
		colMap[i] = dbCol
		if dbCol == "tags" {
			hasTagsColumn = true
		}
	}

	// CSV lacks Tags column but tags/* extras exist -> synthesize a tags column.
	synthesizeTags := !hasTagsColumn && len(tagCol) > 0

	var dbColumns []string
	for i, col := range colMap {
		if !skipCol[i] {
			dbColumns = append(dbColumns, col)
		}
	}
	if synthesizeTags {
		dbColumns = append(dbColumns, "tags")
	}
	dbColumns = append(dbColumns, "source_filename")

	log.Printf("  %s: %d columns, loading...", filename, len(headers))

	tx, err := conn.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	rows := make([][]any, 0, 10000)
	totalRows := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, fmt.Errorf("row %d: %w", totalRows+1, err)
		}

		extraTags := make(map[string]string)
		for idx, dbKey := range tagCol {
			if idx < len(record) {
				v := strings.TrimSpace(record[idx])
				if v != "" {
					extraTags[dbKey] = v
				}
			}
		}

		var row []any
		for i, val := range record {
			if skipCol[i] {
				continue
			}
			val = strings.TrimSpace(val)
			col := colMap[i]

			if val == "" {
				if col == "tags" && len(extraTags) > 0 {
					merged, _ := json.Marshal(extraTags)
					row = append(row, string(merged))
					continue
				}
				row = append(row, nil)
				continue
			}

			switch {
			case col == "tags":
				if len(extraTags) > 0 {
					var existing map[string]any
					if err := json.Unmarshal([]byte(val), &existing); err == nil {
						for k, v := range extraTags {
							if _, exists := existing[k]; !exists {
								existing[k] = v
							}
						}
						merged, _ := json.Marshal(existing)
						row = append(row, string(merged))
					} else {
						log.Printf("  %s: row %d: malformed Tags JSON, storing NULL", filename, totalRows+1)
						row = append(row, JSONOrNil(val))
					}
				} else {
					row = append(row, JSONOrNil(val))
				}
			case focusNumericColumns[col]:
				n, err := strconv.ParseFloat(val, 64)
				if err != nil {
					return 0, fmt.Errorf("row %d col %s: bad numeric %q: %w", totalRows+1, col, val, err)
				}
				row = append(row, n)
			case focusTimestampColumns[col]:
				t, err := ParseTimestamp(val)
				if err != nil {
					return 0, fmt.Errorf("row %d col %s: bad timestamp %q: %w", totalRows+1, col, val, err)
				}
				row = append(row, t)
			default:
				row = append(row, val)
			}
		}
		if synthesizeTags {
			if len(extraTags) > 0 {
				merged, _ := json.Marshal(extraTags)
				row = append(row, string(merged))
			} else {
				row = append(row, nil)
			}
		}
		row = append(row, filename)

		rows = append(rows, row)

		if len(rows) >= 10000 {
			n, err := focusCopyRows(ctx, tx, dbColumns, rows)
			if err != nil {
				return 0, fmt.Errorf("COPY at row %d: %w", totalRows, err)
			}
			totalRows += int(n)
			rows = rows[:0]
			log.Printf("  %s: %d rows so far...", filename, totalRows)
		}
	}

	if len(rows) > 0 {
		n, err := focusCopyRows(ctx, tx, dbColumns, rows)
		if err != nil {
			return 0, fmt.Errorf("COPY final: %w", err)
		}
		totalRows += int(n)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit: %w", err)
	}

	return totalRows, nil
}

func focusCopyRows(ctx context.Context, tx pgx.Tx, columns []string, rows [][]any) (int64, error) {
	return tx.CopyFrom(
		ctx,
		pgx.Identifier{"focus_data_table"},
		columns,
		pgx.CopyFromRows(rows),
	)
}
