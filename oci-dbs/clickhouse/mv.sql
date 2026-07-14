CREATE MATERIALIZED VIEW `oci-finops`.oci_cost_report_attributed_mv
REFRESH EVERY 1 HOUR OFFSET 10 MINUTE
ENGINE = MergeTree ORDER BY (product_service, lineitem_intervalusagestart)
AS SELECT * FROM `oci-finops`.oci_cost_report_attributed;
