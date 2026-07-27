# oci-costing

Download OCI cost report CSV files and load them into ClickHouse (and/or PostgreSQL).

Runs in production as an hourly Kubernetes CronJob on OKE cluster `develop-aiplat`
(namespace `oci-finops`), loading ClickHouse db `oci-finops`. See **How it works** below
and `docs/deployment.md` for the full deployment runbook.

Two binaries built from this repo:

| Binary | Role |
|---|---|
| `oci-load-bills` | Loader CLI. Reads `.csv.gz` files, writes ClickHouse and/or Postgres (`WRITE_CH`/`WRITE_PG`). |
| `oci-pull-bills` | Orchestrator. Downloads reports from OCI Object Storage (in-process), then invokes `oci-load-bills`. Container entrypoint. |

Two report formats supported by the loader:

- **FOCUS** — OCI FOCUS cost reports (FinOps Open Cost & Usage Specification) → `focus_data_table`
- **OCI proprietary** — `cost-csv/...` reports → `oci_cost_report`

## How it works

```mermaid
flowchart LR
    CRON[CronJob hourly UTC<br/>ns oci-finops] --> PB[oci-pull-bills]
    PB -- "OKE Workload Identity<br/>(IAM endorse policy)" --> OS[(Oracle Object Storage<br/>namespace bling)]
    OS -- "FOCUS + cost .csv.gz<br/>today + yesterday" --> DATA[/emptyDir /data/]
    PB -- exec --> LB[oci-load-bills]
    DATA --> LB
    LB -- "dedupe by source_filename" --> CH[(ClickHouse<br/>clickhouse-dev, db oci-finops)]
```

1. CronJob fires hourly; pod authenticates to OCI via **Workload Identity** (no stored keys —
   a root-tenancy IAM policy endorses exactly this cluster + namespace + ServiceAccount).
2. `oci-pull-bills` downloads FOCUS + proprietary cost CSVs for **today + yesterday** from
   Oracle's reporting bucket into an ephemeral volume.
3. It then execs `oci-load-bills` per report type, which parses and inserts into ClickHouse.
4. Every file dedupes by `source_filename`, so hourly re-runs no-op on already-loaded files
   and missed runs self-heal on the next tick.

## Prerequisites

- Go 1.26+
- ClickHouse with the target tables created (see `oci-dbs/clickhouse/`) — and/or PostgreSQL (`oci-dbs/postgresql/`) if `WRITE_PG=true`
- **For OCI Object Storage access** — auth depends on where you run:
  - **Production (OKE):** set `OCI_AUTH=workload_identity`. A root-tenancy IAM policy endorses the pod's cluster+namespace+ServiceAccount tuple. No `~/.oci/config` needed. See `docs/deployment.md`.
  - **Local dev:** `~/.oci/config` with a profile that has READ on the reporting bucket. The loader auto-detects this when `OCI_AUTH` is unset.
- **For Cloud Advisor (`oci-pull-advisor`)** — the same principal additionally needs `optimizer` read. Under OKE Workload Identity add an `allow` (not a dynamic group) to the same root-tenancy policy, with the identical workload conditions:
  `allow any-user to read optimizer-api-family in tenancy where all { request.principal.type='workload', request.principal.cluster_id='<cluster-ocid>', request.principal.namespace='oci-finops', request.principal.service_account='oci-costing-load' }`
  Missing this shows as `404 NotAuthorizedOrNotFound` on `ListEnrollmentStatuses` (OCI reports authz as 404). Full statement + `oci iam policy update` gotchas in `docs/deployment.md`.

## Setup

```bash
cp .env.example .env
# fill values
```

Connection config: set **either** `DATABASE_URL` (preferred — single Postgres URI) **or** the legacy `DB_*` set. `DATABASE_URL` wins if both are present.

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | preferred | Full Postgres URI, e.g. `postgres://user:pw@host:5432/ocianalytics?sslmode=verify-full&sslrootcert=./dbsystem.pub`. Password must be URL-encoded. |
| `DB_USER` | fallback | PostgreSQL username (ignored if `DATABASE_URL` set) |
| `DB_PASSWORD` | fallback | PostgreSQL password |
| `DB_HOST` | fallback | OCI PostgreSQL host FQDN |
| `DB_PORT` | fallback | Port (default `5432`) |
| `DB_NAME` | fallback | Database name (default `ocianalytics`) |
| `DB_SSLROOTCERT` | fallback | Path to SSL root cert (default `./dbsystem.pub`) |
| `OCI_AUTH` | no | Force a specific OCI auth method: `workload_identity` (prod / OKE), `resource_principal`, `instance_principal`, `api_key`, or `auto`/unset for chain |
| `OCI_PROFILE` | local only | Profile in `~/.oci/config` — used only when the api-key path runs (`OCI_AUTH=api_key` or auto-chain falls through to it). Ignored under Workload Identity. Default `DEFAULT`. |
| `OCI_DATA_DIR` | no | Working dir for downloaded CSVs (default `./data` locally, `/data` in container) |
| `TAGS_CONFIG` | no | Path to `tags.yaml` (default: next to the binary, i.e. `src/tags.yaml` for local builds; ConfigMap-mounted in k8s) |
| `WRITE_PG` | no | Enable Postgres sink (default `true`) |
| `WRITE_CH` | no | Enable ClickHouse sink (default `false`) |
| `CLICKHOUSE_URL` | required if `WRITE_CH=true` | CH DSN. Scheme must match port: `http://user:pw@host:8123/oci-finops` (HTTP — what prod uses) or `clickhouse://user:pw@host:9000/...` (native). Mismatch → handshake error. |

In Kubernetes the loader receives `CLICKHOUSE_URL` from Secret `oci-costing-secret` (key `clickhouse_url`) with `WRITE_CH=true`, `WRITE_PG=false`. See `docs/deployment.md`.

## Build

```bash
cd src
go build -o oci-load-bills ./cmd/oci-load-bills
go build -o oci-pull-bills ./cmd/oci-pull-bills
```

## Usage

### Loader (`oci-load-bills`)

```bash
oci-load-bills focus <file.csv.gz|folder>   # FOCUS reports
oci-load-bills oci   <file.csv.gz|folder>   # OCI proprietary reports
```

Exit codes: `0` = all loaded/skipped, `2` = partial failure (some files failed but batch continued), `1` = setup error.

### Orchestrator (`oci-pull-bills`)

```bash
oci-pull-bills            # yesterday + today (UTC)
oci-pull-bills 2026-04-01 # specific date
oci-pull-bills 2026-04    # entire month
```

Steps: downloads FOCUS + cost CSVs for the requested interval(s) into `$OCI_DATA_DIR/{focus,cost}/`, then runs `oci-load-bills focus` and `oci-load-bills oci` over those dirs. Loaders are idempotent — files dedupe by `source_filename`.

### Cloud Advisor snapshot (`oci-pull-advisor`)

```bash
oci-pull-advisor            # snapshot dated today (UTC)
oci-pull-advisor 2026-07-17 # snapshot for a specific day
```

Calls four OCI Cloud Advisor (optimizer) APIs — `ListCategories`, `ListRecommendations`, `ListResourceActions`, `ListHistories` — for the tenancy root (subtree enabled, all pages), enriches each resource action with its recommendation/category context, and writes a dated snapshot to ClickHouse `advisor_recommendations` + `advisor_history` (see `oci-dbs/clickhouse/04_advisor.sql`). Guarded by `ListEnrollmentStatuses`: if the tenancy's Advisor enrollment is not ACTIVE it logs and exits without writing. Idempotent — a same-day re-run deletes that day's rows first. `resource_id` joins to `oci_cost_report.product_resourceid` (Compute/volumes/LB; Object Storage buckets have no cost match). Runs daily via the `oci-advisor-load` CronJob. Needs the `optimizer` read IAM grant (see Prerequisites).

## Loader details

### FOCUS

Loads into `focus_data_table`. CSV headers map 1:1 to DB columns. `Tags` JSON column is merged with extras from `tags/*` columns listed in `tags.yaml`. If the CSV omits a `Tags` column, one is synthesized from `tags/*` extras.

### OCI proprietary

Loads into `oci_cost_report`. Fixed columns map by header. *All* `tags/*` columns are dynamically detected and rolled into a single JSONB `tags` column. Correction rows (`lineItem/isCorrection`) are stored as-is; use the `oci_cost_report_effective` view for corrected data.

## ClickHouse dual-write

The loader can write each file to Postgres, ClickHouse, or both, controlled by `WRITE_PG`/`WRITE_CH`:

| Phase | `WRITE_PG` | `WRITE_CH` | Notes |
|---|---|---|---|
| 1 — CH validation | `true` | `true` | Dual-write; PG stays source of truth. |
| 2 — dual-write bake | `true` | `true` | Run until diffs match (see migration plan §7), then flip. |
| 3 — CH cutover | `false` | `true` | PG sink disabled once CH is trusted. **← current production state (since 2026-07-11)** |

Semantics are **strict AND**: a file is only `DONE`/archived if *every enabled* sink succeeds; if any enabled sink fails, the file `FAIL`s, is not archived, and the process exits `2`. Each sink dedupes independently by `source_filename`, so a retry only re-runs the sink(s) that failed — no cross-DB transaction needed.

See `docs/clickhouse-migration-plan.md` for the full design and `oci-dbs/clickhouse/README.md` for schema/DDL notes.

## Features

- `.csv.gz` (gzipped) inputs
- Batch `COPY` writes (10,000 rows per batch)
- Per-file transaction (all-or-nothing)
- Per-file dedupe via `source_filename`
- Per-file timeout + fail-soft (one bad file does not kill the batch)
- Tree summary output per run
- In-process OCI Object Storage downloads (no external binary)

## Deploy to OCI Kubernetes (OKE)

Dockerfile lives in `src/`, k8s manifests at repo root. See `docs/deployment.md` for build + apply steps.

```
src/Dockerfile                # multi-stage, scratch runtime, 2 static binaries (~18 MB)
scripts/deploy.sh             # build + push + apply (subcommands: build|apply|trigger|status|all)
scripts/make-secret.sh        # generate app secret (ClickHouse DSN)
k8s-oci-finops-extract.yml           # ServiceAccount + hourly/daily CronJobs (ns must pre-exist)
oci-finops-extract-configmap.yml     # tags allow-list ConfigMap
oci-costing-secret.example.yml
```

## Repo layout

```
.
├── src/                    # Go module root + Docker
│   ├── cmd/
│   │   ├── oci-load-bills/ # loader CLI
│   │   └── oci-pull-bills/ # orchestrator (download + load)
│   ├── internal/
│   │   ├── config/         # env + tags.yaml
│   │   ├── loader/         # focus + oci loaders (PG)
│   │   ├── chsink/         # focus + oci loaders (ClickHouse)
│   │   ├── ocireports/     # OCI Object Storage download (ported, see NOTICE)
│   │   └── output/         # tree summary
│   ├── vendor/             # vendored deps (offline builds behind corp proxy)
│   ├── tags.yaml           # extra tags/* keys to merge into JSONB (build input; k8s uses ConfigMap)
│   └── Dockerfile
├── scripts/                # deploy.sh, make-secret.sh, daily_load.sh
├── k8s-oci-finops-extract.yml     # k8s manifests (repo root)
├── oci-finops-extract-configmap.yml
├── oci-dbs/clickhouse/     # CH DDL + PG→CH backfill script
├── scripts/daily_load.sh   # legacy bash wrapper (kept for local dev; container uses oci-pull-bills)
├── baml_src/               # BAML source: NL→SQL agent (types, prompts, SQL guard + tests)
├── service/                # nl-cost-agent FastAPI service (generated baml_sdk + app/ + tests/)
├── k8s-nl-cost-agent.yml   # agent Deployment + Service (oci-finops ns)
├── nl-cost-agent-secret.example.yml
```

## Database scripts

Schema dumped from the live DB via `oci-dbs/postgresql/dump.sh` (uses `pg_dump`, reads `.env`):

| File | Purpose |
|---|---|
| `00_full_schema.sql` | Complete `public` schema — parents, all monthly partitions, indexes, sequences, views |
| `grants_dump.sql` | `GRANT`/`REVOKE` snapshot — apply per environment |
| `dump.sh` | Regenerates the above from the live DB |

Both fact tables use monthly `PARTITION BY RANGE` on the period-start timestamp; new partitions must be created before the month begins (loader does not auto-create). See `oci-dbs/postgresql/README.md` for the partition DDL template and view explanation.

## NL cost query agent (`service/`)

Ask OCI cost questions in plain English; a BAML-typed LLM function generates ClickHouse SQL, a deterministic guard enforces SELECT-only + row limits, and the service executes and summarizes. LLM logic lives in `baml_src/` (edit with `baml check` / `baml test`; regenerate SDK with `baml generate`).

### `POST /ask`

Request:

```json
{"question": "total cost by service last month", "max_rows": 500}
```

`max_rows` optional (default 500, hard cap 10000).

Responses:

| Status | Body | Meaning |
|---|---|---|
| 200 | `{"sql", "explanation", "caveats": [], "rows": [], "truncated": bool, "summary"}` | success; `truncated: true` = more rows exist than `max_rows` |
| 422 | `{"detail": "<reason>"}` | question refused (off-topic) or unsafe SQL blocked by guard |
| 502 | `{"detail": "<error>"}` | LLM gateway or ClickHouse failure |

```mermaid
sequenceDiagram
    participant U as Client
    participant S as FastAPI /ask
    participant L as LLM gateway (BAML GenerateQuery)
    participant G as Guard (deterministic)
    participant C as ClickHouse oci-finops
    U->>S: POST /ask {question, max_rows}
    S->>L: question + static schema context
    L-->>S: Query{sql} | Refusal (→ 422)
    S->>G: check_sql + inject LIMIT max_rows+1
    G-->>S: GuardOk | GuardError (→ 422)
    S->>C: HTTP SELECT (read-only)
    C-->>S: rows + meta (Decimal→number normalized)
    S->>L: Summarize(question, sql, sample rows)
    S-->>U: 200 {sql, rows, truncated, summary}
```

### `GET /health`

200 `{"status":"ok"}` when ClickHouse answers `SELECT 1`; 503 otherwise. Used by k8s probes.

```mermaid
flowchart LR
    P[k8s probe] --> H[/GET /health/] --> C[(ClickHouse SELECT 1)] -->|ok| R200[200 ok]
    C -->|unreachable| R503[503]
```

### Env vars

| Var | Required | Purpose |
|---|---|---|
| `CLICKHOUSE_URL` | yes | DSN with creds; HTTP port coerced to 8123 even for native-shaped DSNs |
| `LLM_BASE_URL` | yes | OpenAI-compatible gateway base URL |
| `LLM_API_KEY` | yes | gateway key |
| `LLM_MODEL` | yes | model name at the gateway |

Service fails fast at startup if any are missing. Secrets deploy via `nl-cost-agent-secret.example.yml` pattern (copy, fill, apply; real file gitignored).

### Run

```
cd service
uv sync && uv run pytest            # unit tests (no LLM/CH needed)
uv run uvicorn app.main:app         # local run (env vars above required)
docker build -t nl-cost-agent .     # image
kubectl apply -f k8s-nl-cost-agent.yml
```

## Known issues

### Stale / incomplete resource tags in OCI billing export

OCI's cost-and-usage export bakes tags into each line item **at usage time**. Re-tagging
a resource in the OCI console does **not** rewrite already-emitted line items, and there is
often a lag (and occasionally a persistent gap) before the new tags appear in the export at
all. As a result the dashboard can show tag values that differ from the live console.

Confirmed example (2026-07): Autonomous DB
`ocid1.autonomousdatabase.oc1.iad.anuwcljr57qcn2ya2iqp2vlwmtkggoekoklifwpasjapizvmvs4i32cbce5a`
shows `ComponentType=Database` + `ResourceType=AJD` in the console, but the Resources view
renders `Component=AJD`, `Resource type=(untagged)`.

- Root cause is **upstream OCI data**, not the extract/loader, the ClickHouse view, the API,
  or the UI — all faithfully pass through what OCI emits. Verified against the untouched
  source `.gz` (`tags/ATD-Ops.ResourceType` is empty and `ComponentType=AJD` for every
  line item of this resource).
- The tags flipped in the billing feed around **2026-05-16**; correct tags stopped ingesting
  after ~07-10. So it is a real OCI-side tag change, not just short-term propagation lag.
- The `oci_cost_report_attributed` view resolves "latest tags" via
  `argMax(tags, lineitem_intervalusagestart)`, so it can only surface tag values that exist
  in some line item. If OCI never emits the corrected tags, the view cannot show them.

**Diagnosing:** pull the latest `source_filename` for the OCID from `oci_cost_report`, then
inspect that same `.gz` in `data/cost/` — the raw file is the source of truth.

**Mitigation options (not yet implemented):**
- Confirm the corrected tags are saved as *defined* tags on the resource, then wait for the
  next export cycle; re-check the newest source file.
- Optionally harden the view to prefer the most-complete tag map
  (`argMax(tags, (length(mapKeys(tags)), lineitem_intervalusagestart))`) as a tie-break —
  tradeoff: this would mask a *legitimate* tag removal.

## Roadmap

Future enhancements under consideration:

- Archive retention controls for local runs, including cleanup by age or size.
- Better backfill mode for large date ranges without relying on CronJob `emptyDir` capacity.
- Metrics and observability: loaded row counts, failures, durations, and download volume.
- Automated database migration scripts packaged with the loader.
- More resilient CSV handling for optional/new OCI report columns.
- Unit and integration tests with small fixture `.csv.gz` reports.
- Configurable report selection, including optional usage report downloads.
- Improved idempotency using report object metadata or checksum in addition to filename.

## Attribution

`internal/ocireports/` is derived from [`github.com/paolobellardone/oci-reports-download`](https://github.com/paolobellardone/oci-reports-download) (MIT, © 2024 PaoloB). See `NOTICE`.
