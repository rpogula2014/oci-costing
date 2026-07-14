# query-execution-guard

## ADDED Requirements

### Requirement: SELECT-only enforcement
The system SHALL reject any generated SQL that is not a single read-only SELECT statement before execution.

#### Scenario: Mutating statement blocked
- **WHEN** generated SQL contains INSERT, ALTER, DROP, TRUNCATE, or multiple statements
- **THEN** execution is refused and a typed guard error is returned; nothing is sent to ClickHouse

#### Scenario: Valid SELECT passes
- **WHEN** generated SQL is a single SELECT (optionally WITH/CTE)
- **THEN** the guard passes it to execution unchanged

### Requirement: Result and runtime limits
Executed queries SHALL carry an enforced row limit (default 500, caller-adjustable up to a hard cap of 10000) and execution timeout so a bad query cannot flood the service or ClickHouse.

#### Scenario: Missing LIMIT injected
- **WHEN** generated SQL has no LIMIT clause
- **THEN** the executor appends `LIMIT <max_rows+1>` (default 500) before running

#### Scenario: Caller raises the limit
- **WHEN** the request specifies `max_rows` above the hard cap
- **THEN** the limit is clamped to 10000

### Requirement: Truncation detection
The executor SHALL query with `LIMIT max_rows + 1` and report `truncated: true` when more rows exist than returned, so callers know the result is partial.

#### Scenario: Result truncated
- **WHEN** the query matches more rows than `max_rows`
- **THEN** exactly `max_rows` rows are returned with `truncated: true`

### Requirement: Execution against ClickHouse HTTP interface
The system SHALL execute guarded SQL against ClickHouse via its HTTP interface using `CLICKHOUSE_URL` from environment, returning rows as typed data.

#### Scenario: Query succeeds
- **WHEN** a guarded SELECT runs successfully
- **THEN** rows are returned in JSON form along with the executed SQL

#### Scenario: ClickHouse error surfaced
- **WHEN** ClickHouse returns an error (bad column, syntax)
- **THEN** the error message is captured in a typed error result, not an unhandled exception
