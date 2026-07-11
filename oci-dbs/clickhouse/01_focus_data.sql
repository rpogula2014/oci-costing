-- ClickHouse DDL for FOCUS cost reports.
-- Mirrors public.focus_data_table (PostgreSQL) — see oci-dbs/postgresql/00_full_schema.sql.
-- Tags: PG jsonb -> Map(String, String). Dedup is loader-side via source_filename.

CREATE TABLE IF NOT EXISTS focus_data
(
    -- timestamps
    billingperiodstart          DateTime64(3, 'UTC'),
    billingperiodend            Nullable(DateTime64(3, 'UTC')),
    chargeperiodstart           Nullable(DateTime64(3, 'UTC')),
    chargeperiodend             Nullable(DateTime64(3, 'UTC')),

    -- costs / quantities (exact decimal, never Float)
    billedcost                  Nullable(Decimal(20, 10)),
    effectivecost               Nullable(Decimal(20, 10)),
    listcost                    Nullable(Decimal(20, 10)),
    listunitprice               Nullable(Decimal(20, 10)),
    pricingquantity             Nullable(Decimal(20, 10)),
    usagequantity               Nullable(Decimal(20, 10)),

    -- low-distinct dimensions
    availabilityzone            LowCardinality(String),
    billingcurrency             LowCardinality(String),
    chargecategory              LowCardinality(String),
    chargefrequency             LowCardinality(String),
    invoiceissuer               LowCardinality(String),
    pricingcategory             LowCardinality(String),
    pricingunit                 LowCardinality(String),
    provider                    LowCardinality(String),
    publisher                   LowCardinality(String),
    region                      LowCardinality(String),
    resourcetype                LowCardinality(String),
    servicecategory             LowCardinality(String),
    servicename                 LowCardinality(String),
    usageunit                   LowCardinality(String),

    -- ids / free text
    billingaccountid            String,
    billingaccountname          String,
    chargedescription           String,
    chargesubcategory           String,
    commitmentdiscountcategory  String,
    commitmentdiscountid        String,
    commitmentdiscountname      String,
    commitmentdiscounttype      String,
    resourceid                  String,
    resourcename                String,
    skuid                       String,
    skupriceid                  String,
    subaccountid                String,
    subaccountname              String,

    -- oci_* extension columns
    oci_referencenumber         String,
    oci_compartmentid           String,
    oci_compartmentname         LowCardinality(String),
    oci_overageflag             LowCardinality(String),
    oci_unitpriceoverage        Nullable(Decimal(20, 10)),
    oci_billedquantityoverage   Nullable(Decimal(20, 10)),
    oci_costoverage             Nullable(Decimal(20, 10)),
    oci_attributedusage         Nullable(Decimal(20, 10)),
    oci_attributedcost          Nullable(Decimal(20, 10)),
    oci_backreferencenumber     String,

    -- tags: flat string k/v (from Tags JSON merged with tags/* extras per tags.yaml)
    tags                        Map(String, String),

    -- load bookkeeping
    source_filename             String,
    created_at                  DateTime('UTC') DEFAULT now('UTC'),

    INDEX idx_tags_keys mapKeys(tags)   TYPE bloom_filter GRANULARITY 1,
    INDEX idx_tags_vals mapValues(tags) TYPE bloom_filter GRANULARITY 1,
    INDEX idx_src source_filename       TYPE bloom_filter GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(billingperiodstart)
ORDER BY (servicename, region, billingperiodstart);
