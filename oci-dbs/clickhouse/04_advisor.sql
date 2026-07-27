-- ClickHouse DDL for OCI Cloud Advisor (optimizer service) recommendations.
-- Populated by a daily snapshot from the extract job (4 optimizer APIs:
-- ListCategories, ListRecommendations, ListResourceActions, ListHistories).
--
-- Design notes:
--   * snapshot_date stamps every row so opportunity (estimated) and realized
--     (captured) savings can be trended over time — Advisor's own API is
--     live-only and has no history of its own past states.
--   * resource_id is the resource OCID; it joins to oci_cost_report.product_resourceid
--     for Compute / BootVolume / BlockVolume / LoadBalancer. Object Storage buckets
--     carry an ocid1.bucket… id that cost reports do NOT key on (they key buckets by
--     name), so those rows have no cost match — handled LEFT JOIN read-side.
--   * Savings mirror the cost report's Nullable(Decimal(20,10)); the loader rounds
--     Advisor's raw floats (occasionally scientific notation) to currency precision
--     before insert.
--   * Idempotency: the loader deletes the day's rows (WHERE snapshot_date = <run>)
--     before inserting, so a same-day re-run replaces rather than duplicates. Keeps
--     the read side a plain MergeTree scan — no FINAL / dedup needed downstream.

-- Per resource action, per daily snapshot (from ListResourceActions, enriched with
-- the parent recommendation's category / importance / name).
CREATE TABLE IF NOT EXISTS advisor_recommendations
(
    snapshot_date           Date,

    resource_action_id      String,       -- OCID of the optimizer resource action
    recommendation_id       String,       -- OCID of the parent recommendation
    resource_id             String,       -- resource OCID = oci_cost_report.product_resourceid
    resource_name           String,
    resource_type           LowCardinality(String),  -- Compute, BootVolume, BlockVolume, LoadBalancer, ObjectStorage
    compartment_id          String,
    region                  LowCardinality(String),

    recommendation_name     LowCardinality(String),
    category                LowCardinality(String),   -- cost-management, performance, high-availability
    importance              LowCardinality(String),   -- CRITICAL, HIGH, MODERATE, LOW, MINOR
    status                  LowCardinality(String),   -- PENDING, DISMISSED, POSTPONED, IMPLEMENTED
    time_status_begin       Nullable(DateTime64(3, 'UTC')),  -- when the action entered its current status

    estimated_cost_saving   Nullable(Decimal(20, 10)),  -- potential (PENDING items)
    captured_cost_saving    Nullable(Decimal(20, 10)),  -- realized (IMPLEMENTED items)
    currency                LowCardinality(String),

    action_type             LowCardinality(String),   -- e.g. KB_ARTICLE
    action_url              String,

    -- rightsizing detail (present for compute recommendations; null otherwise)
    recommended_shape       String,
    recommended_cpu         Nullable(Float64),
    recommended_memory      Nullable(Float64),
    aggregation_interval    Nullable(UInt16),

    created_at              DateTime('UTC') DEFAULT now('UTC'),

    INDEX idx_resource_id resource_id TYPE bloom_filter GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(snapshot_date)
ORDER BY (snapshot_date, category, resource_id);

-- Fix audit trail (from ListHistories). Advisor returns null names here, so this
-- table is keyed by ids only — never join it on resource_name.
CREATE TABLE IF NOT EXISTS advisor_history
(
    snapshot_date           Date,

    history_id              String,       -- OCID of the history record
    recommendation_id       String,
    resource_id             String,       -- resource OCID (join key)
    resource_type           LowCardinality(String),
    compartment_id          String,

    resource_action_id      String,
    recommendation_name     LowCardinality(String),
    status                  LowCardinality(String),
    time_created            Nullable(DateTime64(3, 'UTC')),  -- ListHistories exposes only timeCreated (no status-begin/end)

    estimated_cost_saving   Nullable(Decimal(20, 10)),
    captured_cost_saving    Nullable(Decimal(20, 10)),
    currency                LowCardinality(String),

    created_at              DateTime('UTC') DEFAULT now('UTC'),

    INDEX idx_resource_id resource_id TYPE bloom_filter GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(snapshot_date)
ORDER BY (snapshot_date, recommendation_name, resource_id);
