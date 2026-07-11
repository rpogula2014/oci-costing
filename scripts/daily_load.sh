#!/bin/bash
# ============================================
# Daily OCI Cost Report Download & Load
# Downloads FOCUS + proprietary cost reports for today and yesterday,
# then loads both into PostgreSQL.
#
# Usage:
#   ./daily_load.sh                        # today + yesterday
#   ./daily_load.sh 2026-04-01             # specific date
#   ./daily_load.sh 2026-04                # entire month
#
# Prerequisites:
#   - oci-reports-download binary in OCI_REPORTS_BIN path
#   - oci-load-bills binary in OCI_COSTING_BIN path
#   - ~/.oci/config with valid profile
#   - .env file with DB credentials
# ============================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="${OCI_DATA_DIR:-$ROOT_DIR/data}"
OCI_REPORTS_BIN="${OCI_REPORTS_BIN:-$HOME/git/personal/oci-reports-download/oci-reports-download}"
OCI_COSTING_BIN="${OCI_COSTING_BIN:-$ROOT_DIR/src/oci-load-bills}"
OCI_PROFILE="${OCI_PROFILE:-FOCUSREPORTS-NEW}"

# --- Date handling ---
if [ $# -ge 1 ]; then
    REPORT_DATE="$1"
else
    TODAY=$(date +%Y-%m-%d)
    YESTERDAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
    REPORT_DATE=""
fi

# --- Setup directories ---
FOCUS_DIR="$DATA_DIR/focus"
COST_DIR="$DATA_DIR/cost"
mkdir -p "$FOCUS_DIR" "$COST_DIR"

LOG_FILE="$DATA_DIR/daily_load_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "OCI Cost Report Daily Load"
log "=========================================="

# --- Download reports ---
download_reports() {
    local report_type="$1"
    local output_dir="$2"
    local interval="$3"
    local label="$4"

    log "Downloading $label reports for interval: $interval"
    cd "$output_dir"
    "$OCI_REPORTS_BIN" \
        --report-type "$report_type" \
        --report-interval "$interval" \
        --profile "$OCI_PROFILE" \
        2>&1 | tee -a "$LOG_FILE"
    cd "$ROOT_DIR"
}

if [ -n "$REPORT_DATE" ]; then
    # Specific date or month provided
    download_reports "focus" "$FOCUS_DIR" "$REPORT_DATE" "FOCUS"
    download_reports "cost" "$COST_DIR" "$REPORT_DATE" "OCI proprietary"
else
    # Today + yesterday
    log "Processing dates: $YESTERDAY and $TODAY"

    download_reports "focus" "$FOCUS_DIR" "$YESTERDAY" "FOCUS (yesterday)"
    download_reports "focus" "$FOCUS_DIR" "$TODAY" "FOCUS (today)"
    download_reports "cost" "$COST_DIR" "$YESTERDAY" "OCI proprietary (yesterday)"
    download_reports "cost" "$COST_DIR" "$TODAY" "OCI proprietary (today)"
fi

# --- Load into PostgreSQL ---
log "=========================================="
log "Loading reports into PostgreSQL"
log "=========================================="

cd "$ROOT_DIR"

log "Loading FOCUS reports from $FOCUS_DIR"
"$OCI_COSTING_BIN" focus "$FOCUS_DIR" 2>&1 | tee -a "$LOG_FILE"

log "Loading OCI proprietary reports from $COST_DIR"
"$OCI_COSTING_BIN" oci "$COST_DIR" 2>&1 | tee -a "$LOG_FILE"

log "=========================================="
log "Daily load complete"
log "=========================================="
