# Design: nl-cost-query-agent

## Context

Repo has a Python OCI cost pipeline loading ClickHouse (`oci-finops` DB, ~1.4M rows in `oci_cost_report`, views `oci_cost_report_effective` and `oci_cost_report_attributed`, plus `focus_data`) and a static HTML dashboard. BAML toolchain 0.14.1 is initialized (`baml.toml`, `baml_src/main.baml`). Dev machine reaches LLMs only via a localhost proxy (`127.0.0.1:8787`); no shared gateway key exists in the repo env. Deployment target is the aiplat OKE cluster, `oci-finops` namespace, following existing manifest patterns (`k8s-oci-costing.yml`, `*-secret.example.yml`).

## Goals / Non-Goals

**Goals:**
- All LLM + workflow logic in BAML (typed NL→SQL, refusal path, summarization).
- Thin FastAPI shell over generated Python `baml_sdk`: `POST /ask`, `GET /health`.
- Deterministic safety guard (SELECT-only, LIMIT injection) in plain code, not LLM.
- Deployable image + OKE manifests with secret-based config.

**Non-Goals:**
- Dashboard integration (later change).
- Conversation memory / multi-turn chat.
- Query result caching, auth on the endpoint (cluster-internal service first).
- Anomaly explainer (separate change).

## Decisions

1. **BAML brain + FastAPI shell (B) over `baml pack` binary (A).** Shop standard is FastAPI on OKE; gives health checks, metrics path, and Python ecosystem. BAML holds prompts/types; regeneration keeps the boundary typed.
2. **Guard in Python/BAML plain code, not the LLM.** SELECT-only check and LIMIT injection are deterministic string/AST checks — Rule 5: code answers, model doesn't. LLM output is never trusted for safety.
3. **Typed result union for refusals** (`type AskResult = Query | Refusal`) instead of exceptions — refusal is ordinary control flow, maps cleanly to HTTP 422.
4. **Default table = `oci_cost_report_attributed` view.** Corrections removed and cost-center tags backfilled; matches how the dashboard reports cost. Schema context string in BAML documents all four tables so the model can pick `focus_data` when asked.
5. **Schema context is a static BAML string, not live introspection.** Schema changes rarely; static keeps prompts testable and avoids a ClickHouse round-trip per question. Refresh manually when the pipeline schema changes.
6. **ClickHouse execution from Python (existing driver pattern), not `baml.http.fetch`.** Python side already knows `CLICKHOUSE_URL` handling (DSN scheme/port trap noted in project memory); keeps BAML free of connection plumbing.
7. **LLM client config via env** (`LLM_BASE_URL`, `LLM_API_KEY`) using an OpenAI-compatible provider block in BAML — works with local proxy in dev and a real gateway in-cluster.

## Risks / Trade-offs

- [No in-cluster LLM gateway identified yet] → Blocker for deploy phase; dev/test proceed against localhost proxy. Resolve gateway URL/key before manifest apply.
- [LLM generates wrong-but-valid SQL] → Explanation + executed SQL always returned so users can verify; row limit caps blast radius; read-only DB user recommended.
- [Static schema context drifts from real schema] → ClickHouse errors surface as typed 502/422 with the failing SQL; refresh checklist noted in tasks.
- [Decimal columns render as strings in JSON] → Normalize in Python post-processing before returning rows.

## Migration Plan

Greenfield service; no migration. Deploy = build image, push to registry, apply Secret + Deployment + Service to `oci-finops` ns. Rollback = delete deployment; nothing else depends on it.

## Open Questions

- Which in-cluster LLM gateway/key? (user to provide before deploy task)
- Image registry target (OCIR path) — reuse pipeline image repo?
