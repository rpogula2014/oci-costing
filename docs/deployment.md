# Deploy — OKE CronJob

Hourly CronJob on OKE cluster **develop-aiplat** (namespace `oci-finops`):
downloads OCI cost reports (FOCUS + proprietary) via Workload Identity and
loads them into **ClickHouse** (`clickhouse-dev.oci.atd-us.icd`, db `oci-finops`).

Deployed and verified 2026-07-11. This README records exactly what was done.

## Layout

```
src/                          # Go module root
├── cmd/oci-pull-bills/       # orchestrator (entrypoint)
├── cmd/oci-load-bills/       # DB loader CLI
├── internal/  vendor/
├── Dockerfile                # FROM scratch runtime (~18 MB)
└── Dockerfile.local
scripts/
├── deploy.sh                 # build + push + apply
└── make-secret.sh            # generate the app Secret (ClickHouse DSN)
k8s-oci-costing.yml           # Namespace + ServiceAccount + CronJob (repo root)
oci-costing-configmap.yml     # tags allow-list ConfigMap (repo root)
oci-costing-secret.example.yml
```

## Current deployment (facts)

| Item | Value |
|---|---|
| Cluster | `develop-aiplat` (Enhanced), `ocid1.cluster.oc1.iad.aaaaaaaamwidgxyj2b2seevpb65uy7hh7xibybb4jbwe53yusce3vd25xgxq` |
| kube context | `context-ce3vd25xgxq` (deploy.sh default `KCTX`) |
| Namespace / SA | `oci-finops` / `oci-costing-load` |
| Image | `iad.ocir.io/ido20ydwejhf/app-dev-datasvcs/oci-costing:latest` |
| Schedule | hourly at `:00` UTC, `concurrencyPolicy: Forbid` |
| Sink | ClickHouse only (`WRITE_CH=true`, `WRITE_PG=false`) |
| IAM policy | `oci-costing-workload-usage-report` (root tenancy) |

## Step-by-step: what was done (2026-07-10/11)

### 1. IAM policy (root tenancy, needs Administrators)

Cost/FOCUS files live in **Oracle's** Object Storage — namespace `bling`,
bucket named after our tenancy OCID, inside Oracle's `usage-report` tenancy.
Cross-tenancy access requires an `endorse` policy in the **root compartment**:

```
define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq
endorse any-user to read objects in tenancy usage-report where all {
  request.principal.type = 'workload',
  request.principal.cluster_id = '<cluster-ocid>',
  request.principal.namespace = 'oci-finops',
  request.principal.service_account = 'oci-costing-load' }
```

The 4 `where` conditions ARE the identity — no dynamic group, no stored
credential. **Renaming the namespace or ServiceAccount breaks auth silently**;
policy and manifest must change together.

Created as policy `oci-costing-workload-usage-report`
(`ocid1.policy.oc1..aaaaaaaaam5ttxp7wwrghaz6f3phjysq676ml6tlyq6snranrousba2ntxya`).

### 2. Image build + push

```bash
./scripts/deploy.sh build
```

Corp-proxy (Zscaler TLS interception) breaks any in-build network access, so
the Dockerfile is fully offline:

- no `apk add` — vanilla alpine already ships the CA bundle; Go defaults to UTC without tzdata
- `go build -mod=vendor` — deps vendored, no `proxy.golang.org` fetch
- `.dockerignore` keeps build context ~30 MB (was 1.1 GB: `oci-dbs/` dumps + `data/` CSVs)

### 3. Namespace, secrets

```fish
# kube context must be aiplat:
kubectl config use-context context-ce3vd25xgxq

# App secret — ClickHouse DSN (fish syntax; bash: export CLICKHOUSE_URL=...)
set -x CLICKHOUSE_URL 'http://<user>:<password>@clickhouse-dev.oci.atd-us.icd:8123/oci-finops?secure=false'
./scripts/make-secret.sh | kubectl apply -f -

# Image pull secret — copied from atd-agents ns, extended with iad.ocir.io auth
kubectl get secret ocir-pull -n oci-finops   # type kubernetes.io/dockerconfigjson
```

**DSN gotchas (both hit during setup):**
- scheme `clickhouse://` = native protocol = port **9000**; scheme `http://` = port **8123**.
  Mixing them gives `[handshake] unexpected packet [72]` (72 = 'H' of an HTTP response).
- cluster admission policy requires image repos matching `*.ocir.io` —
  use `iad.ocir.io`, not `ocir.us-ashburn-1.oci.oraclecloud.com` (same registry, different hostname);
  the pull secret must carry auth for the hostname the manifest uses.

### 4. Apply + smoke test

```bash
./scripts/deploy.sh apply
kubectl -n oci-finops create job --from=cronjob/oci-costing-load smoke-1
kubectl -n oci-finops logs -f job/smoke-1
# success: "auth: oke-workload-identity", download_failures=0, load_exit=0
```

## OCI auth

The CronJob sets `OCI_AUTH=workload_identity` — fails fast, no silent fallback
to node identity or API keys. The Go SDK additionally requires two env vars in
the pod spec (already in k8s-oci-costing.yml):

```yaml
- name: OCI_RESOURCE_PRINCIPAL_VERSION
  value: "2.2"
- name: OCI_RESOURCE_PRINCIPAL_REGION
  value: us-ashburn-1
```

Without them: `can not create resource principal, environment variable:
OCI_RESOURCE_PRINCIPAL_VERSION, not present`.

Auth chain modes via `OCI_AUTH`:

| `OCI_AUTH` | Mode | Use |
|---|---|---|
| `workload_identity` | OKE WI only | **production (this CronJob)** |
| `resource_principal` | OCI Functions / RP | other OCI services |
| `instance_principal` | OCI compute VM identity | bare OCI VMs |
| `api_key` | `~/.oci/config` | local dev only |
| `auto` / unset | try wi → rp → ip → api_key | dev convenience |

Active mode is logged at startup: `auth: oke-workload-identity`.

## deploy.sh

```bash
./scripts/deploy.sh                    # build + push + apply
./scripts/deploy.sh build              # build + push only
./scripts/deploy.sh apply              # apply manifest only (patches image: line)
./scripts/deploy.sh trigger            # create a one-off Job, follow logs
./scripts/deploy.sh status             # cronjob + recent jobs + last pod logs
IMAGE_TAG=v0.1.2 ./scripts/deploy.sh   # immutable tag (default: latest)
KCTX=context-xxx ./scripts/deploy.sh   # override kube context
```

`deploy.sh apply` rewrites the `image:` line in `k8s-oci-costing.yml` in place
before applying — don't `kubectl apply -f k8s-oci-costing.yml` by hand.

## Secret keys

| Key | Type | Container mount / env |
|---|---|---|
| `clickhouse_url` | string (DSN) | `env CLICKHOUSE_URL` |

## Verify / operate

```bash
./scripts/deploy.sh status                  # cronjob + jobs + last logs
kubectl -n oci-finops get jobs             # hourly run history (3 ok / 5 failed kept)
./scripts/deploy.sh trigger                 # manual run, stream logs
```

## Notes

- **Runtime image is `FROM scratch`** — two static Go binaries (`oci-pull-bills` orchestrator, `oci-load-bills` loader), no shell. Entrypoint `oci-pull-bills` is the Go port of `daily_load.sh`.
- Storage: `emptyDir` (5 Gi) for `/data`, 256 Mi for `/tmp`. CSVs are throwaway; ClickHouse is the durable store.
- Hourly schedule + `concurrencyPolicy: Forbid` + `activeDeadlineSeconds: 3000` → at most one run at a time.
- Exit codes: `0` = all loaded/skipped, `2` = partial fail, `1` = setup error.
- Per-file dedupe via `source_filename` — hourly re-pulls of today's CSVs no-op; gaps self-heal (each run covers today + yesterday).
- Tags allow-list is a ConfigMap — edit + `kubectl apply`, no image rebuild.
- `WRITE_PG`/`WRITE_CH` are env levers on the CronJob (see `docs/clickhouse-migration-plan.md`). Postgres wiring was removed from the manifest at CH cutover (2026-07-11); re-adding means: secret keys `oci_pgsql` + `oci_pgsql_ca`, `DATABASE_URL` env, pg-cert volume/mount, `WRITE_PG=true`.
- Report-download logic is in-process (`internal/ocireports/`, ported from MIT-licensed `github.com/paolobellardone/oci-reports-download`, see `NOTICE`).

## Tighten later

- Replace `:latest` with an immutable SHA tag (`IMAGE_TAG=$(git rev-parse --short HEAD) ./deploy.sh`).
- Add a `PrometheusRule` alert on `kube_job_status_failed` for this namespace.
- Move the ClickHouse DSN into an OCI Vault Secret synced via External Secrets Operator.
- Dedicated ClickHouse user for the loader instead of `default`.
