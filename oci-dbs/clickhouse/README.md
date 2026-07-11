# ClickHouse schema

ClickHouse DDL for the dual-write migration (see `docs/clickhouse-migration-plan.md`).

| File | Purpose |
|---|---|
| `01_focus_data.sql` | `focus_data` table — FOCUS reports (mirrors PG `focus_data_table`) |
| `02_oci_cost_report.sql` | `oci_cost_report` table + `oci_cost_report_effective` view |
| `backfill_pg_to_ch.sh` | One-time PG → CH backfill of existing data (streaming, resumable) |
| `03_attributed_view.sql` | `oci_cost_report_attributed` — retro-applies each OCID's latest tags (tag-backfill fix); original tags kept in `tags_asbilled` |

Apply:

```bash
clickhouse-client --host <host> --secure -d oci-finops --queries-file 01_focus_data.sql
clickhouse-client --host <host> --secure -d oci-finops --queries-file 02_oci_cost_report.sql
```

## Design notes (differences vs PostgreSQL)

- **No partition pre-creation.** `PARTITION BY toYYYYMM(...)` creates parts automatically on
  insert — the PG monthly-partition DDL chore does not exist here.
- **Plain `MergeTree`, not `ReplacingMergeTree`.** Dedup stays loader-side (pre-insert
  `source_filename` check), same as PG. Merge-time dedup would be async and force `FINAL`
  on every query.
- **Tags** are `Map(String, String)` instead of `jsonb` — OCI tags are flat string k/v pairs.
  Query with `tags['key']`; bloom-filter skip indexes on `mapKeys`/`mapValues` prune granules.
- **Strings are non-nullable.** Empty CSV cell -> `''`, not NULL (cheaper in CH). Only
  numerics and optional timestamps are `Nullable(...)`. Consequence: the effective view
  tests `lineitem_iscorrection != ''` where PG tests `IS NOT NULL`.
- **`Decimal(20,10)`** for all money/quantity columns — exact math, matches PG `numeric(20,10)`.
- **`ORDER BY` is immutable** without a table rebuild. Current keys
  (`servicename, region, time` / `product_service, product_region, time`) assume
  service+region-sliced cost queries — revisit before first production load if the main
  dashboards slice differently.

## `oci_cost_report_effective`

Same semantics as the PG view: hides rows superseded by a correction row
(`c.lineitem_backreferenceno = r.lineitem_referenceno` and same
`lineitem_intervalusagestart`). Correction rows themselves remain visible.
Implemented as `LEFT ANTI JOIN` (ClickHouse translation of `NOT EXISTS`).
