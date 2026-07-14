# Tasks: nl-cost-query-agent

## 1. BAML core (nl-query-generation)

- [x] 1.1 Write schema context string in `baml_src/schema.baml` documenting the 4 tables/views (columns, semantics, attributed-view default)
- [x] 1.2 Define types: `Query {sql, explanation, caveats}`, `Refusal {reason}`, `type AskResult = Query | Refusal`
- [x] 1.3 Define OpenAI-compatible `client<llm>` using `env.LLM_BASE_URL` / `env.LLM_API_KEY`
- [x] 1.4 Write `GenerateQuery(question: string) -> AskResult` LLM function with `${ctx.output_format}` and attributed-view guidance
- [x] 1.5 Write pure BAML guard fn `check_sql(sql) -> bool` + `inject_limit(sql, max)` with `baml test` unit tests on literal SQL strings (no model calls)
- [ ] 1.6 `baml check` + `baml test` pass (DONE, 9/9); live smoke of `GenerateQuery` BLOCKED — no LLM key on dev machine (localhost:8787 is headroom proxy, not a gateway)

## 2. Python service (query-execution-guard + ask-api)

- [x] 2.1 Add `[generator]` block to `baml.toml`, run `baml generate`, verify `baml_sdk` imports
- [x] 2.2 Create `service/` FastAPI app: `POST /ask` → GenerateQuery → guard → ClickHouse execute → summary; refusal → 422; upstream errors → 502
- [x] 2.3 ClickHouse executor using `CLICKHOUSE_URL` (HTTP interface), row LIMIT enforcement, Decimal→float normalization
- [x] 2.4 `GET /health` with ClickHouse ping
- [x] 2.5 pytest: guard unit tests, endpoint tests with mocked BAML/ClickHouse (10/10 pass)
- [ ] 2.6 Manual e2e: BLOCKED — needs real LLM gateway key (same blocker as 1.6/3.3)

## 3. Deployment (agent-deployment)

- [x] 3.1 Dockerfile (uv-based); image builds; /health verified 200 on host with real ClickHouse (container→CH blocked by Docker VM DNS for .icd hosts — works in-cluster)
- [x] 3.2 k8s manifests: `k8s-nl-cost-agent.yml` (Deployment+Service, oci-finops ns, ocir-pull, probes) + `nl-cost-agent-secret.example.yml`
- [ ] 3.3 Resolve in-cluster LLM gateway URL + key with user (open question — BLOCKER)
- [ ] 3.4 Push image to OCIR, apply manifests, verify /health and /ask in-cluster (blocked by 3.3)

## 4. Docs

- [x] 4.1 README: folder structure update, /ask + /health endpoint docs with mermaid flow, env var matrix (Rule 13)
