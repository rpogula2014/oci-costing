# ClickHouse Migration Plan — Dual-Write with PG Kill Switch

**Status:** PLAN (no code yet)
**Date:** 2026-07-09
**Decisions locked:**
- Dual-write PG + CH; a file is successful **only if every enabled sink succeeds** (strict AND).
- Tags stored as `Map(String, String)` in CH (pure map, no raw-JSON fallback column).
- `.env` flags control which sinks are on; PG can be switched off once CH is trusted.

---

## 1. Goals

1. Add ClickHouse as a second write target for both report formats (FOCUS, OCI proprietary).
2. Keep PostgreSQL behavior byte-identical while `WRITE_PG=true`.
3. Migrate `tags` JSONB → CH `Map(String, String)`.
4. Allow phased cutover by flipping env flags only — no code changes, no redeploys beyond config.

Non-goals (this phase): dropping PG code, backfilling historical PG data into CH (separate runbook, §9), query/dashboard migration.

## 2. Env flags

Extend `.env` / `.env.example`:

| Var | Default | Meaning |
|---|---|---|
| `WRITE_PG` | `true` | Enable Postgres sink. |
| `WRITE_CH` | `false` | Enable ClickHouse sink. |
| `CLICKHOUSE_URL` | — | CH DSN (`clickhouse://user:pw@host:9440/oci-finops?secure=true`). Required when `WRITE_CH=true`. |

Startup guards (fatal, fail-loud):
- `WRITE_PG=false` and `WRITE_CH=false` → exit: "no write target enabled".
- `WRITE_CH=true` without `CLICKHOUSE_URL` → exit.
- Parse with strict bool (`true`/`false` only); anything else → exit, never silently default.

Cutover phases:

| Phase | WRITE_PG | WRITE_CH | Notes |
|---|---|---|---|
| 1 (today) | true | false | Current behavior, zero change |
| 2 (dual) | true | true | Strict AND; validation period |
| 3 (CH only) | false | true | PG off; PG code stays for rollback |

## 3. Success semantics (per file)

```
ok_pg = WRITE_PG ? pg.Load(file)  : skipped
ok_ch = WRITE_CH ? ch.Load(file)  : skipped
DONE  = (ok_pg or !WRITE_PG) and (ok_ch or !WRITE_CH)
```

- Any enabled sink fails → file status `FAIL`, file is **not archived**, process exits 2 (unchanged contract with `daily_load.sh` / CronJob).
- Retry next run converges because **each sink does its own dedup**: the sink that already has the file SKIPs, the failed one loads. No cross-DB transaction — idempotency keyed on `source_filename` replaces it.
- Sink order: **CH first, then PG** during dual-write (CH is the one being validated; a PG outage must not block CH backfill). Order is safe either way because both are idempotent.
- Tree output (`internal/output/tree.go`): per-file status becomes per-sink, e.g. `DONE (pg: 12,345 | ch: 12,345)`, `SKIP (pg: skip | ch: skip)`, `FAIL (pg: done | ch: FAIL timeout)`. Mixed skip/done is normal during retries.

## 4. ClickHouse schemas

New dir: `oci-dbs/clickhouse/` — `01_focus_data.sql`, `02_oci_cost_report.sql`, `README.md`.

Type mapping rules (PG → CH):

| PG | CH | Why |
|---|---|---|
| `varchar(N)` id-like / free text | `String` | No length limits needed |
| `varchar` low-distinct (region, service, currency, flags, chargecategory…) | `LowCardinality(String)` | Dictionary encoding, big win on cost data |
| `numeric(20,10)` | `Decimal(20, 10)` | Exact money math preserved (do NOT use Float) |
| `timestamptz` | `DateTime64(3, 'UTC')` | CSV values are UTC; keep ms precision |
| `timestamptz NULL` | `Nullable(DateTime64(3, 'UTC'))` | Only where PG allows NULL |
| `jsonb` tags | `Map(String, String)` | Flat uniform k/v — the locked decision |
| `created_at default now()` | `DateTime('UTC') DEFAULT now('UTC')` | Same audit semantics |

Nullability: keep `Nullable(...)` only for columns the loader actually writes NULL to (numerics/timestamps parsed from empty CSV cells). Strings: empty string instead of NULL — cheaper in CH, and PG loader already treats empty as empty.

### 4.1 `focus_data` (from `focus_data_table`)

All ~50 columns carried over 1:1 (same names, lowercase). Skeleton:

```sql
CREATE TABLE focus_data
(
    billingperiodstart      DateTime64(3, 'UTC'),
    billingperiodend        Nullable(DateTime64(3, 'UTC')),
    chargeperiodstart       Nullable(DateTime64(3, 'UTC')),
    chargeperiodend         Nullable(DateTime64(3, 'UTC')),
    billedcost              Nullable(Decimal(20, 10)),
    effectivecost           Nullable(Decimal(20, 10)),
    listcost                Nullable(Decimal(20, 10)),
    listunitprice           Nullable(Decimal(20, 10)),
    pricingquantity         Nullable(Decimal(20, 10)),
    usagequantity           Nullable(Decimal(20, 10)),
    billingcurrency         LowCardinality(String),
    chargecategory          LowCardinality(String),
    chargefrequency         LowCardinality(String),
    pricingcategory         LowCardinality(String),
    pricingunit             LowCardinality(String),
    provider                LowCardinality(String),
    publisher               LowCardinality(String),
    region                  LowCardinality(String),
    servicecategory         LowCardinality(String),
    servicename             LowCardinality(String),
    usageunit               LowCardinality(String),
    availabilityzone        LowCardinality(String),
    resourceid              String,
    resourcename            String,
    resourcetype            LowCardinality(String),
    skuid                   String,
    skupriceid              String,
    billingaccountid        String,
    billingaccountname      String,
    subaccountid            String,
    subaccountname          String,
    invoiceissuer           LowCardinality(String),
    chargedescription       String,
    chargesubcategory       String,
    commitmentdiscountcategory String,
    commitmentdiscountid    String,
    commitmentdiscountname  String,
    commitmentdiscounttype  String,
    oci_referencenumber     String,
    oci_compartmentid       String,
    oci_compartmentname     LowCardinality(String),
    oci_overageflag         LowCardinality(String),
    oci_unitpriceoverage    Nullable(Decimal(20, 10)),
    oci_billedquantityoverage Nullable(Decimal(20, 10)),
    oci_costoverage         Nullable(Decimal(20, 10)),
    oci_attributedusage     Nullable(Decimal(20, 10)),
    oci_attributedcost      Nullable(Decimal(20, 10)),
    oci_backreferencenumber String,
    tags                    Map(String, String),
    source_filename         String,
    created_at              DateTime('UTC') DEFAULT now('UTC'),

    INDEX idx_tags_keys mapKeys(tags)   TYPE bloom_filter GRANULARITY 1,
    INDEX idx_tags_vals mapValues(tags) TYPE bloom_filter GRANULARITY 1,
    INDEX idx_src source_filename       TYPE bloom_filter GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(billingperiodstart)
ORDER BY (servicename, region, billingperiodstart);
```

### 4.2 `oci_cost_report`

Same rules; partition/order on `lineitem_intervalusagestart`:

```sql
ENGINE = MergeTree
PARTITION BY toYYYYMM(lineitem_intervalusagestart)
ORDER BY (product_service, product_region, lineitem_intervalusagestart)
```

Columns: all `lineitem_*`, `product_*`, `usage_*`, `cost_*` columns carried 1:1 (exact list generated from `oci-dbs/postgresql/00_full_schema.sql` during APPLY), plus `tags Map(String,String)`, `source_filename`, `created_at`, same three bloom indexes.

Correction rows: `lineitem_iscorrection` stored as-is (same as PG). The PG `oci_cost_report_effective` view gets a CH equivalent:

```sql
CREATE VIEW oci_cost_report_effective AS
SELECT * FROM oci_cost_report
WHERE lineitem_iscorrection != 'true'
   OR lineitem_referenceno NOT IN (
        SELECT lineitem_backreferenceno FROM oci_cost_report
        WHERE lineitem_iscorrection = 'true' AND lineitem_backreferenceno != '');
```
(Exact logic copied from the PG view definition during APPLY — verify against `00_full_schema.sql`, do not trust this sketch.)

### 4.3 Deliberate differences from PG

- **No monthly partition pre-creation.** `PARTITION BY toYYYYMM(...)` auto-creates parts. The "create partition before month begins" operational task disappears for CH.
- **Engine is plain `MergeTree`, not `ReplacingMergeTree`.** Dedup handled at load time by the `source_filename` guard (matches PG behavior, deterministic). ReplacingMergeTree's merge-time collapse is async and would need `FINAL` on every query.
- **No NOT NULL enforcement** — CH doesn't enforce constraints the same way; loader remains the gatekeeper.

## 5. Code changes

### 5.1 New: `internal/chsink/` (single new package)

```
internal/chsink/
    conn.go     — Open(ctx) using CLICKHOUSE_URL, clickhouse-go v2 native protocol
    focus.go    — FocusIsAlreadyLoaded(ctx, conn, filename) / FocusLoadFile(...)
    oci.go      — OCIIsAlreadyLoaded(ctx, conn, filename)   / OCILoadFile(...)
```

Mirrors `internal/loader` shape exactly (same function names, same signatures modulo conn type) — a reader of one package can navigate the other.

- Dedup guard: `SELECT count() FROM <table> WHERE source_filename = ?` (pre-insert, same as PG's EXISTS check).
- Insert: `clickhouse-go` v2 batch API (`PrepareBatch` + `Append`), 10,000 rows per flush — same batch size as the PG COPY path.
- Tags: reuse the existing per-row tag-collection logic (FOCUS: `Tags` JSON merged with `tags/*` extras from `tags.yaml`; OCI: all `tags/*` columns) but emit `map[string]string` directly — **no JSON marshal step**. FOCUS `Tags` JSON cells still need one `json.Unmarshal` into `map[string]string` to flatten (values that aren't strings → `fmt.Sprint`ed; note in code, expected rare).
- Per-file "transaction": CH batches aren't transactional across flushes. Mitigation: if a file fails mid-load, delete its partial rows before retry — `ALTER TABLE <t> DELETE WHERE source_filename = ?` is async; instead run the dedup check as `count() > 0` and on retry of a *failed* file issue a lightweight `DELETE ... IN PARTITION` first, or simpler: **single batch per file** (files are ~100k rows max — verify size during APPLY; if files fit one batch, one `batch.Send()` is atomic enough). Decision point flagged for APPLY: measure real file row counts first.

### 5.2 Shared CSV parse (refactor, minimal)

Today parse and PG-write are interleaved inside `FocusLoadFile`/OCI equivalent. To avoid parsing each `.csv.gz` twice:

- Extract row-building (CSV → `[]any` + `map[string]string` tags) into a callback-based walker: `parseFocusRows(path, tagsCfg, fn func(row) error)`.
- PG sink and CH sink each consume the same parsed row. One gzip/CSV pass, two writers.
- **Fallback if refactor grows risky:** parse twice (once per sink). Files are modest; correctness > elegance. Flag at APPLY time.

### 5.3 Orchestration (`cmd/oci-costing/main.go`, `internal/loader/oci.go` main loop)

Per file (both formats):

```
writePG := envBool("WRITE_PG", true)
writeCH := envBool("WRITE_CH", false)
// startup guards from §2

chDone := !writeCH || chsink.IsAlreadyLoaded(...)
pgDone := !writePG || loader.IsAlreadyLoaded(...)
if chDone && pgDone → SKIP, archive
// CH first, then PG (see §3); skip a sink that already has the file
any sink fails → FAIL, no archive, failures++
all enabled sinks done → DONE, archive
```

- Connections opened once at startup, only for enabled sinks. `WRITE_CH=false` → CH code path never touched (phase 1 is a true no-op).
- `oci-load` (orchestrator) needs no changes — it shells out to `oci-costing`, which picks flags up from env.

### 5.4 Dependency

`go.mod` + vendor: add `github.com/ClickHouse/clickhouse-go/v2` (native protocol, first-party, Map type support). Only new dependency.

## 6. Deploy changes (`deploy/`)

- K8s Secret gains key `oci_clickhouse` → `CLICKHOUSE_URL` env (same pattern as `oci_pgsql` → `DATABASE_URL`).
- CronJob env adds `WRITE_PG` / `WRITE_CH` (plain env vars, not secrets — they're the cutover levers).
- CH TLS cert mount if the CH endpoint needs a custom CA (mirror `/etc/pg-certs` pattern). Verify actual CH endpoint requirements at APPLY.

## 7. Validation (dual-write period)

Daily manual (or scripted) check, per table:

```sql
-- PG
SELECT source_filename, count(*), sum(billedcost) FROM focus_data_table
WHERE created_at > now() - interval '2 days' GROUP BY 1 ORDER BY 1;
-- CH
SELECT source_filename, count(), sum(billedcost) FROM focus_data
WHERE created_at > now('UTC') - INTERVAL 2 DAY GROUP BY 1 ORDER BY 1;
```

Match on (filename, rowcount, cost sum) = green. Run for an agreed window (suggest ≥2 weeks incl. one month boundary) before flipping `WRITE_PG=false`.

## 8. Docs to update in the same APPLY (Rule 13)

- `README.md`: env var matrix (3 new vars), dual-write semantics, phase table, CH sections mirroring the PG ones.
- `.env.example`: new vars with comments.
- `oci-dbs/clickhouse/README.md`: schema rationale, no-partition-precreation note, effective-view note.
- `deploy/README.md`: new secret key + env flags.

## 9. Explicitly out of scope (future runbooks)

- Historical backfill PG → CH (`clickhouse-client --query INSERT ... FORMAT` from PG dump, or re-run loader over archived files with `WRITE_PG=false`). Archived source files make re-load the cleanest path.
- Removing PG code after phase 3 bake period.
- Grafana/dashboard/query migration.

## 10. Open questions (resolve before/at APPLY)

1. **Max rows per file?** Determines whether single-batch-per-file atomicity (§5.1) is viable. Check archived files.
2. **CH deployment target** — ✅ resolved: `clickhouse-dev.oci.atd-us.icd`, native protocol port `9000` (dev), db `oci-finops`.
3. **PG `oci_cost_report_effective` view exact definition** — ✅ resolved: copied verbatim from `00_full_schema.sql`.
4. **`ORDER BY` keys** — sketched as (service, region, time); confirm against your actual top queries before creating tables (ORDER BY is immutable without rebuild).

## 11. Task breakdown (APPLY order)

1. ✅ `oci-dbs/clickhouse/` DDL for both tables + README → verify: DDL applies clean on target CH.
2. ✅ Env flag parsing + startup guards → verify: all 4 flag combos behave per §2 table.
3. ✅ `internal/chsink` package → verify: load one real FOCUS + one OCI file into CH, counts match file rows, tags queryable via `tags['key']`.
4. ✅ Orchestration strict-AND wiring + tree output → verify: simulate CH failure (bad URL) → file FAILs, not archived, exit 2; retry after fix → PG SKIPs, CH loads, DONE.
5. Docs + `.env.example` + `deploy/` updates → verify: README env matrix matches code defaults.
6. Dual-write validation window (§7) → verify: 2 weeks green diffs → flip `WRITE_PG=false`.
