#!/usr/bin/env bash
# Deploy oci-costing to OKE (oci-finops ns) as an hourly CronJob.
#
# Prereqs:
#   - docker buildx (amd64 cross-compile from Mac M-series)
#   - kubectl context configured (override with KCTX env)
#   - docker login to OCIR Ashburn (OCI Auth Token, not password)
#   - secret oci-costing-secret present in the target namespace
#     (ClickHouse DSN only — no OCI API key; auth is Workload Identity)
#   - secret ocir-pull (docker-registry) present for image pulls
#   - OKE Workload Identity enabled + root-tenancy IAM policy
#     (see docs/deployment.md)
#
# Usage:
#   ./deploy.sh               # build + push + apply
#   ./deploy.sh build         # build + push only
#   ./deploy.sh apply         # apply manifest only
#   ./deploy.sh trigger       # create a one-off Job from the CronJob
#   ./deploy.sh status        # show cronjob + recent jobs + last pod logs
#   IMAGE_TAG=v0.1.2 ./deploy.sh

set -euo pipefail

# ---- config ----
REGISTRY="iad.ocir.io/ido20ydwejhf/app-dev-datasvcs"
IMAGE_NAME="oci-costing"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

KCTX="${KCTX:-context-ce3vd25xgxq}" # develop-aiplat (OCI-AI); override w/ KCTX=...
NS="oci-finops"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"   # in src/; set DOCKERFILE=Dockerfile.local for ZScaler/local builds
CRONJOB_NAME="oci-costing-load"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$ROOT_DIR/k8s-oci-finops-extract.yml"
CONFIGMAP="$ROOT_DIR/oci-finops-extract-configmap.yml"
cd "$SCRIPT_DIR"

log() { printf '\033[1;34m[deploy]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

kctx_arg() { [[ -n "$KCTX" ]] && printf -- '--context %s' "$KCTX" || printf ''; }
kc() { kubectl $(kctx_arg) -n "$NS" "$@"; }

build_and_push() {
  [[ -f "$ROOT_DIR/src/$DOCKERFILE" ]] || die "$DOCKERFILE not found in $ROOT_DIR/src"
  if [[ ! -d "$ROOT_DIR/src/vendor" ]]; then
    log "vendoring deps (go mod vendor)"
    (cd "$ROOT_DIR/src" && go mod vendor) || die "go mod vendor failed"
  fi
  log "build linux/amd64 → $IMAGE (context=$ROOT_DIR/src, Dockerfile=src/$DOCKERFILE)"
  docker buildx build \
    --platform linux/amd64 \
    -f "$ROOT_DIR/src/$DOCKERFILE" \
    -t "$IMAGE" \
    --push \
    "$ROOT_DIR/src"
  log "pushed $IMAGE"
}

RENDERED=""

render_manifest() {
  # The committed manifest carries the literal `image_to_be_deployed` token that the GoCD
  # deploy script seds. Render to a temp copy so the token survives in git.
  local img_escaped
  img_escaped=$(printf '%s' "$IMAGE" | sed 's#[\#&]#\\&#g')
  RENDERED=$(mktemp "${TMPDIR:-/tmp}/cronjob.XXXXXX")
  trap 'rm -f "$RENDERED"' EXIT
  sed -E "s#(^[[:space:]]*image:[[:space:]]*).*#\1${img_escaped}#" "$MANIFEST" > "$RENDERED"
  log "rendered image → $IMAGE"
}

apply_manifest() {
  [[ -f "$MANIFEST" ]] || die "$MANIFEST not found"
  # The Namespace object no longer ships in the manifest (GoCD's deploy principal can't create
  # namespaces), and the workload-identity IAM policy is bound to ns/$NS — fail loud if missing.
  kubectl $(kctx_arg) get ns "$NS" >/dev/null 2>&1 || die "namespace $NS missing — create it first (see docs/deployment.md IAM section)"
  render_manifest
  log "apply $CONFIGMAP + $MANIFEST → ns/$NS"
  kubectl $(kctx_arg) apply -f "$CONFIGMAP"
  kubectl $(kctx_arg) apply -f "$RENDERED"
  log "current cronjob"
  kc get cronjob "$CRONJOB_NAME" -o wide || true
}

trigger() {
  local job="manual-$(date +%s)"
  log "create one-off Job from CronJob/$CRONJOB_NAME → $job"
  kc create job --from="cronjob/$CRONJOB_NAME" "$job"
  log "waiting for pod..."
  kc wait --for=condition=Ready pod -l "job-name=$job" --timeout=60s || true
  log "follow logs (Ctrl-C to stop streaming; job continues)"
  kc logs -f -l "job-name=$job" --tail=200 || true
}

status() {
  log "cronjob"
  kc get cronjob "$CRONJOB_NAME" -o wide || true
  echo
  log "recent jobs"
  kc get jobs --sort-by=.metadata.creationTimestamp | tail -10 || true
  echo
  log "last pod logs (most recent job)"
  local last
  last=$(kc get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)
  if [[ -n "$last" ]]; then
    kc logs -l "job-name=$last" --tail=100 || true
  else
    log "no jobs found"
  fi
}

usage() {
  grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
}

cmd="${1:-all}"
case "$cmd" in
  build)   build_and_push ;;
  apply)   apply_manifest ;;
  trigger) trigger ;;
  status)  status ;;
  all)     build_and_push; apply_manifest ;;
  -h|--help|help) usage ;;
  *) die "unknown cmd: $cmd (try: build|apply|trigger|status|all)" ;;
esac
