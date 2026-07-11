#!/usr/bin/env bash
# One command: pull fresh aggregates from ClickHouse and rebuild the dashboard.
#
# Usage:
#   ./refresh.sh              # extract + build only
#   ./refresh.sh --publish    # extract + build + publish (unlisted) to the report portal
#
# Publish requires: report-publish binary (REPORT_PUBLISH_BIN or on PATH) and
# REPORT_TOKEN exported in the environment.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML="$SCRIPT_DIR/finops-deep-dive.html"

bash "$SCRIPT_DIR/extract.sh"
node "$SCRIPT_DIR/build.mjs"
echo "done → $HTML"

if [ "${1:-}" = "--publish" ]; then
    BIN="${REPORT_PUBLISH_BIN:-}"
    if [ -z "$BIN" ]; then
        if command -v report-publish >/dev/null 2>&1; then BIN=report-publish
        elif [ -x "$HOME/git/ATD-AI/tools/report-portal/dist/report-publish" ]; then
            BIN="$HOME/git/ATD-AI/tools/report-portal/dist/report-publish"
        else
            echo "ERROR: report-publish not found (set REPORT_PUBLISH_BIN or add to PATH)" >&2; exit 1
        fi
    fi
    : "${REPORT_TOKEN:?REPORT_TOKEN not set — export it before --publish}"
    "$BIN" -unlisted "$HTML"
fi
