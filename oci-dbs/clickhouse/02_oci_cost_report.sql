-- ClickHouse DDL for OCI proprietary cost reports.
-- Mirrors public.oci_cost_report (PostgreSQL) — see oci-dbs/postgresql/00_full_schema.sql.
-- Tags: PG jsonb -> Map(String, String). Dedup is loader-side via source_filename.

CREATE TABLE IF NOT EXISTS oci_cost_report
(
    lineitem_referenceno        String,
    lineitem_tenantid           String,
    lineitem_intervalusagestart DateTime64(3, 'UTC'),
    lineitem_intervalusageend   Nullable(DateTime64(3, 'UTC')),

    product_service             LowCardinality(String),
    product_compartmentid       String,
    product_compartmentname     LowCardinality(String),
    product_region              LowCardinality(String),
    product_availabilitydomain  LowCardinality(String),
    product_resourceid          String,
    product_description         String,

    usage_billedquantity        Nullable(Decimal(20, 10)),
    usage_billedquantityoverage Nullable(Decimal(20, 10)),
    usage_attributedusage       Nullable(Decimal(20, 10)),

    cost_subscriptionid         String,
    cost_productsku             String,
    cost_unitprice              Nullable(Decimal(20, 10)),
    cost_unitpriceoverage       Nullable(Decimal(20, 10)),
    cost_mycost                 Nullable(Decimal(20, 10)),
    cost_mycostoverage          Nullable(Decimal(20, 10)),
    cost_currencycode           LowCardinality(String),
    cost_billingunitreadable    LowCardinality(String),
    cost_skuunitdescription     LowCardinality(String),
    cost_overageflag            LowCardinality(String),
    cost_attributedcost         Nullable(Decimal(20, 10)),

    -- correction handling: rows stored as-is; superseded rows filtered by the
    -- oci_cost_report_effective view below. Empty string = "not a correction"
    -- (PG NULL maps to '' — the view condition accounts for this).
    lineitem_iscorrection       LowCardinality(String),
    lineitem_backreferenceno    String,

    -- tags: all tags/* CSV columns rolled into flat string k/v
    tags                        Map(String, String),

    -- load bookkeeping
    source_filename             String,
    created_at                  DateTime('UTC') DEFAULT now('UTC'),

    INDEX idx_tags_keys mapKeys(tags)   TYPE bloom_filter GRANULARITY 1,
    INDEX idx_tags_vals mapValues(tags) TYPE bloom_filter GRANULARITY 1,
    INDEX idx_src source_filename       TYPE bloom_filter GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(lineitem_intervalusagestart)
ORDER BY (product_service, product_region, lineitem_intervalusagestart);

-- Effective view: hide rows superseded by a correction row.
-- PG source: a row r is excluded when a correction row c exists with
--   c.lineitem_backreferenceno = r.lineitem_referenceno
--   AND c.lineitem_iscorrection IS NOT NULL
--   AND c.lineitem_intervalusagestart = r.lineitem_intervalusagestart
-- CH translation: NOT EXISTS -> LEFT ANTI JOIN on (referenceno, intervalusagestart).
-- PG "iscorrection IS NOT NULL" -> CH "iscorrection != ''" (loader writes '' for empty cells).
CREATE VIEW IF NOT EXISTS oci_cost_report_effective AS
SELECT r.*
FROM oci_cost_report AS r
LEFT ANTI JOIN
(
    SELECT lineitem_backreferenceno, lineitem_intervalusagestart
    FROM oci_cost_report
    WHERE lineitem_iscorrection != '' AND lineitem_backreferenceno != ''
) AS c
ON  c.lineitem_backreferenceno   = r.lineitem_referenceno
AND c.lineitem_intervalusagestart = r.lineitem_intervalusagestart;
