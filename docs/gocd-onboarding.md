# GoCD onboarding — oci-finops-extract

Target: `ATD-DevSecOps/gocd-msa_material-gh` branch `feature/ATDCLOUD-3913-oci-migration`
(OCI-aware build/deploy scripts: `build_go.sh`, `gocd_deploy.sh`, `get_secrets_oracle.sh`).

**Authoritative source = the shell scripts, not `docs/guides/getting-started.md`.** That guide
shows a `kubernetes/` subdirectory; the scripts read manifests from the **repo root**
(`gocd_deploy.sh:268,334,335,467,468`) and env files from `configurations/`
(`gocd_deploy.sh:224`). Follow the layout below.

## Required repo layout

All filenames derive from the GitHub repo name → `repo_name = oci-finops-extract`.

```
oci-finops-extract/
├── ci-cd/
│   └── oci-finops-extract.properties        # build_go.sh:189, gocd_deploy.sh:168
├── src/
│   └── Dockerfile                           # docker build context = src/ (build_go.sh:80)
├── configurations/
│   ├── dev.env                              # gocd_deploy.sh:224 ($envType.env from Mongo)
│   ├── qa.env
│   ├── xat.env
│   └── prod.env                             # var_replace.env is generated here at deploy time
├── k8s-oci-finops-extract.yml               # kubectl apply -n $platformNamespace
├── oci-finops-extract-configmap.yml         # token-substituted (gocd_deploy.sh:334)
├── k8s-servicemonitor-oci-finops-extract.yml # applied unconditionally into ns `monitoring` (:468)
└── dashboard/oci-finops-extract.json        # optional; skip with grafanaDashboard=No
```

`secrets/` is created at runtime by `get_secrets_oracle.sh` — do not commit it.

## Rename table (current → required)

| Current | Required |
|---|---|
| `cicd/` (empty) | `ci-cd/oci-finops-extract.properties` |
| `k8s-oci-costing.yml` | `k8s-oci-finops-extract.yml` |
| `oci-costing-configmap.yml` | `oci-finops-extract-configmap.yml` |
| — | `k8s-servicemonitor-oci-finops-extract.yml` (missing) |
| — | `configurations/*.env` (missing) |
| `src/Dockerfile` | unchanged ✅ |

## ci-cd/oci-finops-extract.properties

```properties
serviceType=go
cloudProvider=oracle      # validated at build_go.sh:196-205; routes SCM + OCIR + OKE
project=<ask DevSecOps>   # Mongo lookup key AND secrets filename prefix
deployOn=core,omega    # material-repo default; confirm with DevSecOps
generateImage=Yes
grafanaDashboard=No
# deploy_job_url=deploy_oci-finops-extract_ATD-AI   # optional override
```

## Manifest changes needed

1. **Image must be the literal token.** `gocd_deploy.sh:340,363` runs
   `sed -i "s#image_to_be_deployed#<registry>/<project>/oci-finops-extract:latest-<sf_br>#g"`.
   Both hardcoded `iad.ocir.io/.../oci-costing:latest` values must become `image_to_be_deployed`,
   otherwise the sed no-ops and every deploy ships a stale tag. OCIR repo is auto-created
   (`ensure_ocir_repo_for_image`) — note the image path segment becomes `oci-finops-extract`.
2. **Namespace stays pinned to `oci-finops`.** The `kind: Namespace` object was dropped (the deploy
   principal likely cannot create namespaces; the ns already exists), but every resource keeps
   `namespace: oci-finops` because the OKE Workload Identity IAM policy is bound to
   `request.principal.namespace = 'oci-finops'` + `service_account = 'oci-costing-load'`.
   Deploy runs `kubectl apply -n ${platformNamespace}` → **`platformNamespace` in the Mongo row
   must be `oci-finops`**, otherwise kubectl errors on the mismatch (which is the desired loud
   failure — deploying elsewhere would silently break resource-principal auth).
3. **Substitution tokens** injected from `configurations/<env>.env`: `ServiceName`, `SvcName`,
   `hpaSrvName`, `PltNamespace`. Anything left hardcoded will not vary per environment.
4. **Keep the literal `imagePullSecrets:` line — it is load-bearing.**
   `add_oracle_image_pull_secret` (`gocd_deploy.sh:262`, invoked at `:367`) auto-inserts
   `- name: ocir-secret`, but its awk only matches `template:` at 2-space / `spec:` at 4-space
   indent — i.e. Deployment nesting. Our CronJobs nest at 6/8 (`spec:` → `jobTemplate:` →
   `spec:` → `template:` → `spec:`), so the awk would never fire and would
   `exit 2` → the caller `exit 1`s **before** `kubectl apply`. We are saved only by the
   function's early return: `grep -q "imagePullSecrets:"`. Our manifest already has it
   (`k8s-oci-costing.yml:40,133`, secret `ocir-pull`) — **never remove that line.**
   Confirm `ocir-pull` (not `ocir-secret`) exists in the target namespace, or rename to match
   whatever DevSecOps provisions.

## BLOCKER — workload kind

`gocd_deploy.sh:469` runs `kubectl rollout restart deploy ${SERVICE_NAME}` with **no kind guard**;
the only guard present is for StatefulSet (:471). This repo ships two **CronJobs**, so that
command fails on every deploy. Neither script uses `set -e`, and GoCD grades the task on the
script's *final* exit code — so this is worse than a red build: **the CronJobs get applied, the
restart failure is logged as noise, and the stage may still report green.** A silent partial
deploy. The post-deploy `pod_health_check` also assumes a Deployment.

Options, in preference order:
1. **Ask DevSecOps for a CronJob branch** alongside the StatefulSet guard — skip rollout restart,
   or `kubectl create job --from=cronjob/<name>` for a smoke run. Correct fix, follows precedent.
2. Hack: add a trivial Deployment named `oci-finops-extract` so `rollout restart` succeeds.
   Unblocks today, adds a useless pod.

## External dependencies (cannot be satisfied from this repo)

- **Mongo platform row** keyed `{project, safeBranchName}`, inserted by DevSecOps. Keys the scripts
  require: `codeRepo`, `platformNpeProject`, `envType`, `platformNamespace`, `platformRegion`,
  `ocirNpeCompartmentOcid`, `okeClusterOcid`, `okeCompartmentOcid`, `okeKubeEndpoint`
  (`build_go.sh:246-252`, `gocd_deploy.sh:410-413`).
- **OCI Vault secrets** named `^${project}-secrets-${envType}` — `get_secrets_oracle.sh` renders them
  into `secrets/${project}-secrets-${envType}.yml` and applies it. Our ClickHouse/OCI creds must live there.
- **`ocir-secret`** imagePullSecret present in the target namespace.
- **GoCD pipelines** `build_go_oci-finops-extract_ATD-AI` and `deploy_oci-finops-extract_ATD-AI`.
- **SCM auth for the `ATD-AI` org** — origin is `github.com/ATD-AI/oci-finops-extract`, while every
  material-repo example is `ATD-DevSecOps`. Confirm the GoCD GitHub App is installed on `ATD-AI`.
- GoCD agent env: `OCI_CLI_CONFIG_FILE`, `OCI_CLI_PROFILE`, `OCI_COMPARTMENT_OCID`, `OCI_VAULT_OCID`,
  `OCI_REGION`, `OCI_TENANCY`.

## Branch flow

`feature/*` → build only, **no push, no deploy** (`build_go.sh` exits after docker build).
`develop` → build + push `latest-develop` + deploy. Then `qa` → `xat` → `master` (retag only, no rebuild).
Current branch `feature/oci-cost-pipeline` will never deploy — first real deploy needs `develop`.

## Open questions for DevSecOps

1. `project=` value and the Mongo platform row for it?
2. `platformNamespace` for dev **must be `oci-finops`** (IAM policy binding) — confirm.
3. CronJob support in `gocd_deploy.sh`, or use the placeholder-Deployment hack?
4. Is the GoCD GitHub App installed on the `ATD-AI` org?
5. Re-enable the configmap apply in `gocd_deploy.sh:464-466`, or do we apply the tags ConfigMap manually?
6. Is the imagePullSecret in `oci-finops` named `ocir-pull` (ours) or `ocir-secret` (script default)?

## Gotchas found in the scripts

- **The ConfigMap is never applied by the pipeline.** `gocd_deploy.sh:464-466` — all three
  configmap `kubectl apply/delete` lines are commented out. `oci-finops-extract-configmap.yml`
  (tags allow-list, mounted at `/etc/oci-costing/tags.yaml`) must be applied out-of-band, or the
  CronJob pods fail to mount. Ask DevSecOps to re-enable, or treat the ConfigMap as a one-time
  manual apply and re-apply whenever `tags.yaml` changes.
- **`configurations/<env>.env` is a blind global sed.** Each `key=value` becomes
  `sed "s/key/value/g"` over `k8s-*.yml` and the servicemonitor (`gocd_deploy.sh:332-335,358-363`).
  Keys must be unique placeholder strings, never plain words. Also: a `-` anywhere in the file
  switches `:305` to swimlane-prefix parsing (`key-value` per swimlane), so avoid hyphens unless
  that's what you want. Ours carry only `replace_logical_env=<env>` (currently a no-op token).
- **`PltNamespace` is substituted in the servicemonitor only** (`:366`), not in `k8s-*.yml`.
- **`project=msa` is a guess and is the one value where a wrong answer is dangerous.** It is the
  Mongo lookup key, so a wrong value silently resolves a *different* platform row → wrong
  `platformNamespace`, `ocirNpeCompartmentOcid` and OKE cluster, i.e. it deploys somewhere real
  instead of erroring. It is also the secrets filename prefix (`${project}-secrets-${envType}.yml`)
  and the cluster fallback `${swimlane}-${project}`. Confirm before the first run.
- **`envType` must be one of `dev|qa|xat|prod`** to match our `configurations/` filenames. If the
  Mongo row says e.g. `develop` or `nonprod`, `gocd_deploy.sh:224-225` just creates the file empty
  and the run continues — no error, substitutions silently skipped.
- **`imagePullSecrets` name is `ocir-pull`** in our manifest; the script would have injected
  `ocir-secret`. Whichever DevSecOps provisions in `oci-finops` must match.

## What was applied in this repo

- `k8s-oci-costing.yml` → `k8s-oci-finops-extract.yml`; `Namespace` object removed, both
  `image:` values → `image_to_be_deployed`, `namespace: oci-finops` retained on SA + both CronJobs.
- `oci-costing-configmap.yml` → `oci-finops-extract-configmap.yml`.
- Added `ci-cd/oci-finops-extract.properties`, `configurations/{dev,qa,xat,prod}.env`,
  `k8s-servicemonitor-oci-finops-extract.yml`.
- `scripts/deploy.sh`: new paths; renders the image into a temp copy so the
  `image_to_be_deployed` token survives in git; fails fast if ns `oci-finops` is absent.
- Filename references updated in `README.md` and `docs/deployment.md`.

`openspec/changes/nl-cost-query-agent/design.md` still references the old `k8s-oci-costing.yml`
name; left as-is since it is a historical design record.
