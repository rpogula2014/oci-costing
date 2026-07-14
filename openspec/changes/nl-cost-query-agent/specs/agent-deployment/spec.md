# agent-deployment

## ADDED Requirements

### Requirement: Containerized service
The system SHALL provide a Dockerfile building the FastAPI service with the generated `baml_sdk`, runnable with only environment variables for configuration.

#### Scenario: Local container run
- **WHEN** the image is run with `CLICKHOUSE_URL`, `LLM_BASE_URL`, `LLM_API_KEY` set
- **THEN** the service starts, `/health` returns 200, and `/ask` answers questions

### Requirement: OKE deployment manifests
The system SHALL provide Kubernetes manifests (Deployment, Service, Secret template) targeting the `oci-finops` namespace, following the repo's existing manifest conventions.

#### Scenario: Secrets not committed
- **WHEN** manifests are committed
- **THEN** real credentials appear only in a `*.example.yml` template; actual secret values are applied out-of-band (matching existing `oci-costing-secret.example.yml` pattern)

### Requirement: In-cluster LLM gateway configuration
The deployment SHALL take the LLM gateway base URL and API key from a Kubernetes Secret; localhost proxy URLs SHALL NOT be baked into the image or manifests.

#### Scenario: Missing gateway config fails fast
- **WHEN** the pod starts without `LLM_BASE_URL` or `LLM_API_KEY`
- **THEN** the service exits (or reports unhealthy) with a clear config error rather than failing on first request
