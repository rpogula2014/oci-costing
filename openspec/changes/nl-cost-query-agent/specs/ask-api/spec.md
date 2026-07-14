# ask-api

## ADDED Requirements

### Requirement: POST /ask endpoint
The service SHALL expose `POST /ask` accepting `{"question": string, "max_rows": int?}` (default 500, hard cap 10000) and returning `{"sql": string, "explanation": string, "rows": array, "truncated": bool, "summary": string}` on success, with appropriate HTTP status codes for failures.

#### Scenario: Truncated result surfaced
- **WHEN** the query matches more rows than `max_rows`
- **THEN** the response contains `truncated: true` and the summary advises narrowing the question or using a higher `max_rows`

#### Scenario: Successful question
- **WHEN** a valid cost question is POSTed
- **THEN** the response is 200 with generated SQL, result rows, and a short natural-language summary

#### Scenario: Refused question
- **WHEN** the agent refuses (off-topic or guard-blocked SQL)
- **THEN** the response is 422 with a JSON body containing the refusal reason

#### Scenario: Upstream failure
- **WHEN** the LLM gateway or ClickHouse is unreachable
- **THEN** the response is 502 with an error detail, and the failure is logged

### Requirement: GET /health endpoint
The service SHALL expose `GET /health` reporting service liveness and ClickHouse reachability.

#### Scenario: Healthy
- **WHEN** the service is up and ClickHouse responds to a ping query
- **THEN** `/health` returns 200 with `{"status": "ok"}`
