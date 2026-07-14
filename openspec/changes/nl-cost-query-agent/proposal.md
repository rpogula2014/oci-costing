# Proposal: nl-cost-query-agent

## Why

OCI cost data (1.4M+ line items in ClickHouse `oci-finops`) is only reachable through the static dashboard or hand-written SQL. FinOps stakeholders can't ask ad-hoc questions ("what did OKE cost last month by compartment?") without an engineer. A typed NL→SQL agent makes the dataset self-serve.

## What Changes

- New BAML project layer (`baml_src/`) holding all LLM logic: NL→ClickHouse-SQL generation, SQL safety guard (SELECT-only), result summarization — typed end to end.
- Generated Python `baml_sdk` consumed by a new thin FastAPI service exposing `POST /ask` (question in, SQL + rows + summary out) and `GET /health`.
- Dockerfile + k8s manifests to deploy the service to OKE (aiplat cluster, `oci-finops` namespace), config via env: `CLICKHOUSE_URL`, LLM gateway URL + key as k8s Secret.
- Agent queries the `oci_cost_report_attributed` view by default (corrections removed, cost-center tags backfilled).

## Capabilities

### New Capabilities
- `nl-query-generation`: BAML LLM function turning a natural-language cost question plus schema context into validated ClickHouse SQL with an explanation.
- `query-execution-guard`: SELECT-only enforcement, row/time limits, and execution of generated SQL against ClickHouse.
- `ask-api`: FastAPI endpoint contract (`POST /ask`, `GET /health`) wrapping the BAML workflow.
- `agent-deployment`: Container image + OKE manifests + secret/config contract for running the agent in-cluster.

### Modified Capabilities

(none — first spec-tracked change in this repo)

## Impact

- New code: `baml_src/*.baml`, `service/` (FastAPI app), `Dockerfile`, k8s manifests.
- Dependencies: BAML toolchain 0.14.1, `baml_sdk` Python package, FastAPI/uvicorn.
- Systems: ClickHouse `oci-finops` DB (read-only), LLM gateway (needs in-cluster reachable URL + key — currently only a localhost proxy exists on the dev machine; blocker to resolve before deploy).
- Existing pipeline and dashboard untouched.
