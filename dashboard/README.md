# FinOps deep-dive dashboard

Self-contained HTML dashboard over the ClickHouse cost data
(`oci-finops.oci_cost_report_attributed` — corrections + latest-tags-per-OCID
backfill applied). No server, no build step to view — open the file:

```bash
open dashboard/finops-deep-dive.html
```

## Refresh with fresh data

```bash
./dashboard/refresh.sh             # rebuild only
./dashboard/refresh.sh --publish   # rebuild + publish (unlisted) to the report portal
```

Requires: `clickhouse-client` (or the `clickhouse` multi-tool) on PATH, `node`,
and `CLICKHOUSE_URL` in the repo `.env`. `--publish` additionally needs the
`report-publish` binary (PATH or `REPORT_PUBLISH_BIN`) and `REPORT_TOKEN`
exported. The portal URL stays constant across republishes (same slug);
unlisted hides it from the portal index but the direct link works for anyone
who has it.

| File | Purpose |
|---|---|
| `finops-deep-dive.html` | The dashboard (data embedded; ~1.5MB; works offline). **Generated — do not edit; edit `src/` and rebuild** |
| `src/template.html` | Document shell: head, body markup, `__STYLES__`/`__DATA__`/`__APP__` markers |
| `src/styles.css` | All CSS |
| `src/js/*.js` | App modules, concatenated into one script in filename order (`020-…` → `210-…`) |
| `extract.sh` | Pulls two JSONEachRow aggregates from ClickHouse into `data/` |
| `build.mjs` | Dictionary-encodes the aggregates and assembles `src/` + data → the HTML |
| `refresh.sh` | extract + build |
| `data/` | Extracted JSON (regenerated on every refresh; safe to delete) |

Source layout (`src/js/`): `020-palette-state` (state, dims, formatters) ·
`030-date-helpers` (bucketing) · `040-filtering` · `050-aggregation` ·
`060-tooltip` · `070-stacked-bar-chart-svg` (trend) · `080-ranked-breakdown` ·
`090-tabs` · `100-drill-through` · `110-movers` · `120-resource-movers` ·
`130-compare-periods` · `140-untagged-watch` · `150-kpis` ·
`160-detail-table-export` · `170-controls-wiring` · `180-main-update` ·
`190-url-state` (shareable hash) · `200-text-matches` · `210-ocid-lookup` (+ boot).
Modules share one scope — no imports; order matters only for top-level
statements, so new modules slot in by picking a filename number.

## What's in the dashboard

- **Controls**: Day/Week/Month granularity · group-by (cost center, environment,
  component, compartment, service, resource type, resource name) · date-range
  presets · per-dimension filters — everything cross-filters live.
- **KPIs**: total, latest month, MoM (complete months), 7-day run-rate,
  untagged spend, top-group share.
- **Spend over time**: stacked SVG bars, hover tooltips, stable entity→color.
- **Breakdown + Top movers**: ranked share bars; latest complete period vs
  prior (partial period excluded).
- **Untagged spend watch**: trend of cost missing `ATD-Billing.CostCenter`
  after tag backfill — the *genuine* attribution gap.
- **OCID lookup**: search by OCID fragment or resource name → total,
  first/last billed, latest tag chips, cost-over-time at the selected
  granularity.
- **Detail table**: top 500 rows at the current grain incl. resource OCID,
  CSV export.

## Data notes

- `rname` shows `untagged · <product_description>` when `ATD-Ops.ResourceName`
  is missing, so unnamed spend is still identifiable.
- Zero-cost resources (idle VNICs, boot volumes) are excluded from the OCID
  index.
- Latest day/period is usually partial — MoM and movers exclude it on purpose.

## TODO

- **Tier 2 deployment — live-serving app on k8s.** Replace the embedded
  `__DATA__` payload with a small Go API that queries ClickHouse live and
  serves JSON to the same front-end (`src/` split already isolates data from
  app code — swap the payload for a `fetch()` at boot). Deployment + Service +
  internal Ingress; reuse the loader CronJob's ClickHouse secret and
  securityContext patterns from `deploy/`. Decide before building: auth
  (internal ingress vs oauth2-proxy/SSO), refresh cadence vs live queries,
  and payload budget (embedded HTML is fine until multi-year data).
