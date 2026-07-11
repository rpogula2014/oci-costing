#!/bin/bash
# Generates oci-costing-secret. ClickHouse only — OCI auth comes from
# Workload Identity at runtime, no API key needed.
#
#   - clickhouse_url = ClickHouse DSN (CLICKHOUSE_URL)
#
# Usage (scheme must match port: http:// = 8123, clickhouse:// = native 9000):
#   export CLICKHOUSE_URL='http://user:pass@clickhouse-dev.oci.atd-us.icd:8123/oci-finops?secure=false'
#   ./make-secret.sh | kubectl apply -f -   # fish: set -x CLICKHOUSE_URL '...'

set -euo pipefail

: "${CLICKHOUSE_URL:?}"

kubectl create secret generic oci-costing-secret \
  --namespace=oci-finops \
  --from-literal=clickhouse_url="$CLICKHOUSE_URL" \
  --dry-run=client -o yaml
