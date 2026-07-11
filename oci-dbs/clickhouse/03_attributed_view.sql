-- Tag-backfill view: resources are often tagged AFTER creation, so early billing
-- rows carry empty/partial tags. This view retroactively applies each resource's
-- (product_resourceid = OCID) latest-known tags to all of its rows.
--
-- Semantics:
--   * "latest" = tags from the OCID's most recent line item that has a
--     non-empty ATD-Billing.CostCenter (a tag-bearing row).
--   * Rows whose OCID has no tagged row anywhere (or no resourceid) keep
--     their as-billed tags.
--   * Original tags preserved in tags_asbilled.
--   * Built on oci_cost_report_effective, so corrections are applied too.
--   * Non-destructive and self-updating: as new tagged rows load, "latest"
--     advances automatically. Do NOT mutate the base table for this.
--
-- Use this view for chargeback/attribution reporting; use _effective for
-- as-billed reporting.

CREATE VIEW IF NOT EXISTS oci_cost_report_attributed AS
WITH latest AS (
    SELECT product_resourceid,
           argMax(tags, lineitem_intervalusagestart) AS ltags
    FROM oci_cost_report
    WHERE product_resourceid != '' AND tags['ATD-Billing.CostCenter'] != ''
    GROUP BY product_resourceid
)
SELECT r.* EXCEPT (tags),
       if(l.ltags['ATD-Billing.CostCenter'] != '', l.ltags, r.tags) AS tags,
       r.tags AS tags_asbilled
FROM oci_cost_report_effective AS r
LEFT JOIN latest AS l ON l.product_resourceid = r.product_resourceid;
