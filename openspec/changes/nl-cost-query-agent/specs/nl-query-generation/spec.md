# nl-query-generation

## ADDED Requirements

### Requirement: Generate ClickHouse SQL from natural language
The system SHALL provide a BAML LLM function that accepts a natural-language cost question and returns a typed result containing ClickHouse SQL, a plain-English explanation, and any caveats.

#### Scenario: Simple aggregate question
- **WHEN** the user asks "total cost by service last month"
- **THEN** the function returns SQL selecting `product_service` and `sum(cost_mycost)` from `oci-finops.oci_cost_report_attributed` grouped by service and filtered to the previous calendar month

#### Scenario: Question includes schema context
- **WHEN** any question is submitted
- **THEN** the prompt includes the table schema context (columns, view semantics) and `${ctx.output_format}` so output parses into the typed result

### Requirement: Default to the attributed view
Generated SQL SHALL target `oci-finops.oci_cost_report_attributed` unless the question explicitly requires raw or FOCUS data.

#### Scenario: Cost-center question
- **WHEN** the user asks about cost by cost center or tag
- **THEN** the SQL reads the `tags` map from `oci_cost_report_attributed` (backfilled cost-center tags), not the raw table

### Requirement: Unanswerable questions are refused with a reason
The function SHALL return a refusal variant (no SQL) when the question cannot be answered from the schema.

#### Scenario: Off-topic question
- **WHEN** the user asks something unrelated to OCI cost data (e.g., "what's the weather")
- **THEN** the result is a typed refusal explaining the agent only answers OCI cost questions
