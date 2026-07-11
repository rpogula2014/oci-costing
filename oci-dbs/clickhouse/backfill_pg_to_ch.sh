#!/usr/bin/env bash
# ============================================
# One-time backfill: PostgreSQL -> ClickHouse
#
# Streams existing rows from focus_data_table and oci_cost_report (PG)
# into focus_data and oci_cost_report (CH) with no intermediate files:
#   psql COPY TO STDOUT (CSV) | clickhouse-client INSERT ... FROM input()
#
# tags jsonb is exported as JSON text and converted in-flight to
# Map(String, String) via JSONExtract.
#
# Idempotency: skips any source_filename already present in CH, so the
# script is safe to re-run and safe alongside dual-write.
#
# Usage:
#   ./backfill_pg_to_ch.sh            # both tables
#   ./backfill_pg_to_ch.sh focus      # focus_data only
#   ./backfill_pg_to_ch.sh oci        # oci_cost_report only
#
# Prerequisites:
#   - psql on PATH; clickhouse-client or the `clickhouse` multi-tool binary (macOS brew cask) on PATH
#   - .env at repo root with PG creds (DATABASE_URL or DB_* set)
#   - CLICKHOUSE_URL in .env, e.g. clickhouse://user:pw@host:9440/oci-finops?secure=true
# ============================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Load .env ---
if [ -f "$REPO_ROOT/.env" ]; then
    set -a; . "$REPO_ROOT/.env"; set +a
fi

# --- PG connection (DATABASE_URL preferred, DB_* fallback — mirrors loader) ---
if [ -n "${DATABASE_URL:-}" ]; then
    PG_CONN="$DATABASE_URL"
else
    : "${DB_USER:?set DATABASE_URL or DB_* in .env}"
    PG_CONN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-5432}/${DB_NAME:-ocianalytics}?sslmode=verify-full&sslrootcert=${DB_SSLROOTCERT:-$REPO_ROOT/dbsystem.pub}"
fi

# --- CH connection (parse clickhouse:// DSN into client flags) ---
: "${CLICKHOUSE_URL:?CLICKHOUSE_URL required in .env}"
proto_stripped="${CLICKHOUSE_URL#clickhouse://}"
CH_CRED="${proto_stripped%%@*}"                    # user:pw
CH_REST="${proto_stripped#*@}"                     # host:port/db?params
CH_USER="${CH_CRED%%:*}"
CH_PASS="${CH_CRED#*:}"
CH_HOST="${CH_REST%%:*}"
CH_PORT_DB="${CH_REST#*:}"
CH_PORT="${CH_PORT_DB%%/*}"
CH_DB="${CH_PORT_DB#*/}"; CH_DB="${CH_DB%%\?*}"
CH_SECURE_FLAG=""
case "$CLICKHOUSE_URL" in *secure=true*) CH_SECURE_FLAG="--secure";; esac

# clickhouse-client on Linux; single `clickhouse` binary with `client` subcommand on macOS (brew cask)
if command -v clickhouse-client >/dev/null 2>&1; then
    CH_BIN=(clickhouse-client)
elif command -v clickhouse >/dev/null 2>&1; then
    CH_BIN=(clickhouse client)
else
    echo "ERROR: neither clickhouse-client nor clickhouse found on PATH" >&2; exit 1
fi

ch() {
    "${CH_BIN[@]}" --host "$CH_HOST" --port "$CH_PORT" $CH_SECURE_FLAG \
        --user "$CH_USER" --password "$CH_PASS" --database "$CH_DB" "$@"
}

TARGET="${1:-all}"
LOG() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# input('<schema>') embeds the schema as a SQL string literal — inner quotes
# (e.g. DateTime64(3,'UTC')) must be backslash-escaped or they end the literal.
esc() { printf '%s' "$1" | sed "s/'/\\\\'/g"; }

# ============================================
# FOCUS
# ============================================
# Column order must match in all three places below (PG SELECT, input() schema,
# CH SELECT). tags travels as JSON text (t_tags String) and becomes a Map.

FOCUS_COLS_PG="billingperiodstart, billingperiodend, chargeperiodstart, chargeperiodend,
billedcost, effectivecost, listcost, listunitprice, pricingquantity, usagequantity,
coalesce(availabilityzone,''), coalesce(billingcurrency,''), coalesce(chargecategory,''),
coalesce(chargefrequency,''), coalesce(invoiceissuer,''), coalesce(pricingcategory,''),
coalesce(pricingunit,''), coalesce(provider,''), coalesce(publisher,''), coalesce(region,''),
coalesce(resourcetype,''), coalesce(servicecategory,''), coalesce(servicename,''),
coalesce(usageunit,''), coalesce(billingaccountid,''), coalesce(billingaccountname,''),
coalesce(chargedescription,''), coalesce(chargesubcategory,''),
coalesce(commitmentdiscountcategory,''), coalesce(commitmentdiscountid,''),
coalesce(commitmentdiscountname,''), coalesce(commitmentdiscounttype,''),
coalesce(resourceid,''), coalesce(resourcename,''), coalesce(skuid,''), coalesce(skupriceid,''),
coalesce(subaccountid,''), coalesce(subaccountname,''), coalesce(oci_referencenumber,''),
coalesce(oci_compartmentid,''), coalesce(oci_compartmentname,''), coalesce(oci_overageflag,''),
oci_unitpriceoverage, oci_billedquantityoverage, oci_costoverage, oci_attributedusage,
oci_attributedcost, coalesce(oci_backreferencenumber,''), coalesce(tags::text,'{}'),
source_filename, created_at"

FOCUS_INPUT_SCHEMA="billingperiodstart DateTime64(3,'UTC'), billingperiodend Nullable(DateTime64(3,'UTC')), chargeperiodstart Nullable(DateTime64(3,'UTC')), chargeperiodend Nullable(DateTime64(3,'UTC')), billedcost Nullable(Decimal(20,10)), effectivecost Nullable(Decimal(20,10)), listcost Nullable(Decimal(20,10)), listunitprice Nullable(Decimal(20,10)), pricingquantity Nullable(Decimal(20,10)), usagequantity Nullable(Decimal(20,10)), availabilityzone String, billingcurrency String, chargecategory String, chargefrequency String, invoiceissuer String, pricingcategory String, pricingunit String, provider String, publisher String, region String, resourcetype String, servicecategory String, servicename String, usageunit String, billingaccountid String, billingaccountname String, chargedescription String, chargesubcategory String, commitmentdiscountcategory String, commitmentdiscountid String, commitmentdiscountname String, commitmentdiscounttype String, resourceid String, resourcename String, skuid String, skupriceid String, subaccountid String, subaccountname String, oci_referencenumber String, oci_compartmentid String, oci_compartmentname String, oci_overageflag String, oci_unitpriceoverage Nullable(Decimal(20,10)), oci_billedquantityoverage Nullable(Decimal(20,10)), oci_costoverage Nullable(Decimal(20,10)), oci_attributedusage Nullable(Decimal(20,10)), oci_attributedcost Nullable(Decimal(20,10)), oci_backreferencenumber String, t_tags String, source_filename String, created_at DateTime('UTC')"

FOCUS_CH_SELECT="billingperiodstart, billingperiodend, chargeperiodstart, chargeperiodend, billedcost, effectivecost, listcost, listunitprice, pricingquantity, usagequantity, availabilityzone, billingcurrency, chargecategory, chargefrequency, invoiceissuer, pricingcategory, pricingunit, provider, publisher, region, resourcetype, servicecategory, servicename, usageunit, billingaccountid, billingaccountname, chargedescription, chargesubcategory, commitmentdiscountcategory, commitmentdiscountid, commitmentdiscountname, commitmentdiscounttype, resourceid, resourcename, skuid, skupriceid, subaccountid, subaccountname, oci_referencenumber, oci_compartmentid, oci_compartmentname, oci_overageflag, oci_unitpriceoverage, oci_billedquantityoverage, oci_costoverage, oci_attributedusage, oci_attributedcost, oci_backreferencenumber, JSONExtract(t_tags, 'Map(String, String)') AS tags, source_filename, created_at"

FOCUS_CH_COLS="billingperiodstart, billingperiodend, chargeperiodstart, chargeperiodend, billedcost, effectivecost, listcost, listunitprice, pricingquantity, usagequantity, availabilityzone, billingcurrency, chargecategory, chargefrequency, invoiceissuer, pricingcategory, pricingunit, provider, publisher, region, resourcetype, servicecategory, servicename, usageunit, billingaccountid, billingaccountname, chargedescription, chargesubcategory, commitmentdiscountcategory, commitmentdiscountid, commitmentdiscountname, commitmentdiscounttype, resourceid, resourcename, skuid, skupriceid, subaccountid, subaccountname, oci_referencenumber, oci_compartmentid, oci_compartmentname, oci_overageflag, oci_unitpriceoverage, oci_billedquantityoverage, oci_costoverage, oci_attributedusage, oci_attributedcost, oci_backreferencenumber, tags, source_filename, created_at"

backfill_focus() {
    LOG "FOCUS: fetching filenames already in CH..."
    ch --query "SELECT DISTINCT source_filename FROM focus_data" > /tmp/ch_focus_done.txt
    LOG "FOCUS: $(wc -l < /tmp/ch_focus_done.txt | tr -d ' ') file(s) already in CH"

    psql "$PG_CONN" -At -c "SELECT DISTINCT source_filename FROM focus_data_table ORDER BY 1" |
    while IFS= read -r fname; do
        if grep -qxF "$fname" /tmp/ch_focus_done.txt; then
            LOG "FOCUS SKIP $fname"
            continue
        fi
        LOG "FOCUS LOAD $fname"
        psql "$PG_CONN" -c "\\copy (SELECT $FOCUS_COLS_PG FROM focus_data_table WHERE source_filename = '$fname') TO STDOUT WITH (FORMAT csv)" |
        ch --query "INSERT INTO focus_data ($FOCUS_CH_COLS) SELECT $FOCUS_CH_SELECT FROM input('$(esc "$FOCUS_INPUT_SCHEMA")') FORMAT CSV"
    done
    LOG "FOCUS: done"
}

# ============================================
# OCI proprietary
# ============================================

OCI_COLS_PG="coalesce(lineitem_referenceno,''), coalesce(lineitem_tenantid,''),
lineitem_intervalusagestart, lineitem_intervalusageend, coalesce(product_service,''),
coalesce(product_compartmentid,''), coalesce(product_compartmentname,''),
coalesce(product_region,''), coalesce(product_availabilitydomain,''),
coalesce(product_resourceid,''), coalesce(product_description,''),
usage_billedquantity, usage_billedquantityoverage, usage_attributedusage,
coalesce(cost_subscriptionid,''), coalesce(cost_productsku,''),
cost_unitprice, cost_unitpriceoverage, cost_mycost, cost_mycostoverage,
coalesce(cost_currencycode,''), coalesce(cost_billingunitreadable,''),
coalesce(cost_skuunitdescription,''), coalesce(cost_overageflag,''),
cost_attributedcost, coalesce(lineitem_iscorrection,''),
coalesce(lineitem_backreferenceno,''), coalesce(tags::text,'{}'),
source_filename, created_at"

OCI_INPUT_SCHEMA="lineitem_referenceno String, lineitem_tenantid String, lineitem_intervalusagestart DateTime64(3,'UTC'), lineitem_intervalusageend Nullable(DateTime64(3,'UTC')), product_service String, product_compartmentid String, product_compartmentname String, product_region String, product_availabilitydomain String, product_resourceid String, product_description String, usage_billedquantity Nullable(Decimal(20,10)), usage_billedquantityoverage Nullable(Decimal(20,10)), usage_attributedusage Nullable(Decimal(20,10)), cost_subscriptionid String, cost_productsku String, cost_unitprice Nullable(Decimal(20,10)), cost_unitpriceoverage Nullable(Decimal(20,10)), cost_mycost Nullable(Decimal(20,10)), cost_mycostoverage Nullable(Decimal(20,10)), cost_currencycode String, cost_billingunitreadable String, cost_skuunitdescription String, cost_overageflag String, cost_attributedcost Nullable(Decimal(20,10)), lineitem_iscorrection String, lineitem_backreferenceno String, t_tags String, source_filename String, created_at DateTime('UTC')"

OCI_CH_SELECT="lineitem_referenceno, lineitem_tenantid, lineitem_intervalusagestart, lineitem_intervalusageend, product_service, product_compartmentid, product_compartmentname, product_region, product_availabilitydomain, product_resourceid, product_description, usage_billedquantity, usage_billedquantityoverage, usage_attributedusage, cost_subscriptionid, cost_productsku, cost_unitprice, cost_unitpriceoverage, cost_mycost, cost_mycostoverage, cost_currencycode, cost_billingunitreadable, cost_skuunitdescription, cost_overageflag, cost_attributedcost, lineitem_iscorrection, lineitem_backreferenceno, JSONExtract(t_tags, 'Map(String, String)') AS tags, source_filename, created_at"

OCI_CH_COLS="lineitem_referenceno, lineitem_tenantid, lineitem_intervalusagestart, lineitem_intervalusageend, product_service, product_compartmentid, product_compartmentname, product_region, product_availabilitydomain, product_resourceid, product_description, usage_billedquantity, usage_billedquantityoverage, usage_attributedusage, cost_subscriptionid, cost_productsku, cost_unitprice, cost_unitpriceoverage, cost_mycost, cost_mycostoverage, cost_currencycode, cost_billingunitreadable, cost_skuunitdescription, cost_overageflag, cost_attributedcost, lineitem_iscorrection, lineitem_backreferenceno, tags, source_filename, created_at"

backfill_oci() {
    LOG "OCI: fetching filenames already in CH..."
    ch --query "SELECT DISTINCT source_filename FROM oci_cost_report" > /tmp/ch_oci_done.txt
    LOG "OCI: $(wc -l < /tmp/ch_oci_done.txt | tr -d ' ') file(s) already in CH"

    psql "$PG_CONN" -At -c "SELECT DISTINCT source_filename FROM oci_cost_report ORDER BY 1" |
    while IFS= read -r fname; do
        if grep -qxF "$fname" /tmp/ch_oci_done.txt; then
            LOG "OCI SKIP $fname"
            continue
        fi
        LOG "OCI LOAD $fname"
        psql "$PG_CONN" -c "\\copy (SELECT $OCI_COLS_PG FROM oci_cost_report WHERE source_filename = '$fname') TO STDOUT WITH (FORMAT csv)" |
        ch --query "INSERT INTO oci_cost_report ($OCI_CH_COLS) SELECT $OCI_CH_SELECT FROM input('$(esc "$OCI_INPUT_SCHEMA")') FORMAT CSV"
    done
    LOG "OCI: done"
}

# ============================================
# Validation: per-table row count + cost sum, PG vs CH
# ============================================
validate() {
    LOG "=== Validation ==="
    LOG "PG focus:  $(psql "$PG_CONN" -At -c 'SELECT count(*), coalesce(sum(billedcost),0) FROM focus_data_table')"
    LOG "CH focus:  $(ch --query 'SELECT count(), coalesce(sum(billedcost),0) FROM focus_data FORMAT TSV')"
    LOG "PG oci:    $(psql "$PG_CONN" -At -c 'SELECT count(*), coalesce(sum(cost_mycost),0) FROM oci_cost_report')"
    LOG "CH oci:    $(ch --query 'SELECT count(), coalesce(sum(cost_mycost),0) FROM oci_cost_report FORMAT TSV')"
}

case "$TARGET" in
    focus) backfill_focus ;;
    oci)   backfill_oci ;;
    all)   backfill_focus; backfill_oci ;;
    *) echo "Usage: $0 [focus|oci|all]" >&2; exit 1 ;;
esac
validate
