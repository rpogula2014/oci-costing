#!/usr/bin/env bash
# Extract FinOps aggregates from ClickHouse for the dashboard.
# Reads CLICKHOUSE_URL from repo .env; writes JSONEachRow files to dashboard/data/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
mkdir -p "$DATA_DIR"

set -a; . "$REPO_ROOT/.env"; set +a
: "${CLICKHOUSE_URL:?CLICKHOUSE_URL missing in .env}"

p="${CLICKHOUSE_URL#clickhouse://}"
cred="${p%%@*}"; rest="${p#*@}"
CH_USER="${cred%%:*}"; CH_PASS="${cred#*:}"
CH_HOST="${rest%%:*}"; pd="${rest#*:}"; CH_PORT="${pd%%/*}"
db="${pd#*/}"; CH_DB="${db%%\?*}"
SECURE=""; case "$CLICKHOUSE_URL" in *secure=true*) SECURE="--secure";; esac

if command -v clickhouse-client >/dev/null 2>&1; then CH_BIN=(clickhouse-client)
elif command -v clickhouse >/dev/null 2>&1; then CH_BIN=(clickhouse client)
else echo "ERROR: clickhouse-client not found" >&2; exit 1; fi

ch() { "${CH_BIN[@]}" --host "$CH_HOST" --port "$CH_PORT" $SECURE \
       --user "$CH_USER" --password "$CH_PASS" --database "$CH_DB" --query "$1"; }

# Daily grain across all analytic dimensions (source: attributed view =
# corrections + latest-tags-per-OCID backfill).
ch "
SELECT toDate(lineitem_intervalusagestart) AS d,
       tags['ATD-Billing.Environment']     AS env,
       tags['ATD-Billing.CostCenter']      AS cc,
       tags['ATD-Billing.ComponentType']   AS comp,
       product_compartmentname             AS cpt,
       product_service                     AS svc,
       tags['ATD-Ops.ResourceType']        AS rtype,
       if(tags['ATD-Ops.ResourceName'] = '',
          concat('untagged · ', product_description),
          tags['ATD-Ops.ResourceName'])    AS rname,
       product_resourceid                  AS ocid,
       round(sum(cost_mycost), 4)          AS cost
FROM oci_cost_report_attributed
GROUP BY d, env, cc, comp, cpt, svc, rtype, rname, ocid
HAVING cost != 0
ORDER BY d
FORMAT JSONEachRow" > "$DATA_DIR/finops_daily.json"
echo "daily:  $(wc -l < "$DATA_DIR/finops_daily.json" | tr -d ' ') rows"

# Per-OCID daily costs + latest tag info (OCID lookup panel).
ch "
SELECT product_resourceid AS ocid,
       toDate(lineitem_intervalusagestart) AS d,
       argMax(tags['ATD-Billing.CostCenter'], lineitem_intervalusagestart)   AS cc,
       argMax(tags['ATD-Billing.Environment'], lineitem_intervalusagestart)  AS env,
       argMax(tags['ATD-Ops.ResourceType'], lineitem_intervalusagestart)     AS rtype,
       argMax(tags['ATD-Ops.ResourceName'], lineitem_intervalusagestart)     AS rname,
       round(sum(cost_mycost), 4) AS cost
FROM oci_cost_report_attributed
WHERE product_resourceid != ''
GROUP BY ocid, d
HAVING cost != 0
ORDER BY ocid, d
FORMAT JSONEachRow" > "$DATA_DIR/finops_ocid.json"
echo "ocid:   $(wc -l < "$DATA_DIR/finops_ocid.json" | tr -d ' ') rows"
