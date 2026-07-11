#!/usr/bin/env bash
# Dump the current ocianalytics public schema into versioned SQL files.
# Reads DB_* from .env in the repo root.
#
# Usage:
#   ./dump.sh
#
# Outputs (overwritten each run):
#   00_full_schema.sql   # complete public schema — DDL only, no owners/grants
#   grants_dump.sql      # GRANT/REVOKE snapshot (curate per environment before applying)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$SCRIPT_DIR"

# shellcheck disable=SC1091
set -a; source "$ROOT_DIR/.env"; set +a
: "${DB_USER:?}" "${DB_PASSWORD:?}" "${DB_HOST:?}" "${DB_NAME:?}"
DB_PORT="${DB_PORT:-5432}"
DB_SSLROOTCERT="${DB_SSLROOTCERT:-$ROOT_DIR/dbsystem.pub}"

URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=verify-full&sslrootcert=${DB_SSLROOTCERT}"

echo "→ 00_full_schema.sql"
pg_dump --no-owner --no-privileges --schema-only --no-comments --schema=public "$URL" \
  > 00_full_schema.sql

echo "→ grants_dump.sql"
pg_dump --no-owner --schema-only --no-comments --schema=public "$URL" \
  | grep -E '^GRANT |^REVOKE ' > grants_dump.sql || true

echo "Done."
ls -la *.sql
