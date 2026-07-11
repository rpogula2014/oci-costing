# PostgreSQL schema — ocianalytics

Snapshot of the `public` schema for the cost-warehouse Postgres, dumped from the live database via `./dump.sh`. **Do not hand-edit** — re-run the dump to refresh.

## Files

| File | Content |
|---|---|
| `dump.sh` | Regenerates the snapshot via `pg_dump`, reads `.env` from repo root. |
| `00_full_schema.sql` | Complete `public` schema — parents, all monthly partitions, indexes, sequences, views. DDL only (no owners or grants). |
| `grants_dump.sql` | `GRANT`/`REVOKE` snapshot, dumped separately so you can curate per environment before applying. |

## Tables

### `focus_data_table`

```
PARTITION BY RANGE (billingperiodstart)         -- TIMESTAMPTZ
indexes:
  idx_fcr_compartment   (oci_compartmentname, servicecategory, resourcetype)
  idx_fcr_source_file   (source_filename)
  idx_fcr_tags          USING GIN (tags)
```

### `oci_cost_report`

```
PARTITION BY RANGE (lineitem_intervalusagestart)  -- TIMESTAMPTZ
indexes:
  idx_ocr_referenceno   (lineitem_referenceno)
  idx_ocr_backreference (lineitem_backreferenceno)  WHERE NOT NULL
  idx_ocr_correction    (lineitem_iscorrection)     WHERE NOT NULL
  idx_ocr_compartment   (product_compartmentname)
  idx_ocr_compartment1  (product_region, product_compartmentname, product_service, product_description)
  idx_ocr_resource      (product_resourceid)
  idx_ocr_source_file   (source_filename)
  idx_ocr_tenant        (lineitem_tenantid)
  idx_ocr_tags          USING GIN (tags)
```

### `oci_cost_report_effective` (view)

Returns only rows **not superseded** by a correction. The loader stores correction rows alongside originals; this view does the `NOT EXISTS` join on `lineitem_backreferenceno` so downstream consumers see the final state.

## Partition strategy

Both tables use monthly partitions named `{table}_YYYY_MM`, covering `[YYYY-MM-01 00:00 UTC, YYYY-MM+1-01 00:00 UTC)`.

Partitions are created out of band — the loader does **not** auto-create them. Before a new month begins, run:

```sql
CREATE TABLE focus_data_table_2026_06 PARTITION OF focus_data_table
  FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');
CREATE TABLE oci_cost_report_2026_06 PARTITION OF oci_cost_report
  FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');
```

A loader run that targets a date with no matching partition fails with `no partition of relation "..." found for row`. Automate with `pg_partman` or a monthly cron.

## Refreshing the snapshot

```bash
./dump.sh
git diff --stat       # confirm changes are intentional
git add *.sql
```

Requires `pg_dump` in PATH and DB creds in repo-root `.env`.
