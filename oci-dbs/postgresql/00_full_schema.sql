--
-- PostgreSQL database dump
--

\restrict OAbbt7eb9lALdhhh2yao9F6fprVTjf92GYbdXV27YNs44RpFzXXWgpsoa5HYU6M

-- Dumped from database version 16.8
-- Dumped by pg_dump version 16.13 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: fcr_backfill_partitions(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fcr_backfill_partitions(from_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_date DATE;
    start_ts TIMESTAMPTZ;
    end_ts TIMESTAMPTZ;
    partition_name TEXT;
    created TEXT := '';
BEGIN
    PERFORM pg_advisory_lock(hashtext('fcr_partition_lock'));

    cur_date := date_trunc('month', from_date)::DATE;
    WHILE cur_date <= date_trunc('month', CURRENT_DATE)::DATE LOOP
        start_ts := make_timestamptz(EXTRACT(YEAR FROM cur_date)::INT, EXTRACT(MONTH FROM cur_date)::INT, 1, 0, 0, 0, 'UTC');
        end_ts := make_timestamptz(EXTRACT(YEAR FROM (cur_date + INTERVAL '1 month'))::INT, EXTRACT(MONTH FROM (cur_date + INTERVAL '1 month'))::INT, 1, 0, 0, 0, 'UTC');
        partition_name := 'focus_data_table_' || to_char(cur_date, 'YYYY_MM');

        IF to_regclass('public.' || partition_name) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF focus_data_table FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_ts, end_ts
            );
            EXECUTE format('GRANT SELECT ON %I TO ocianalytics_readonly', partition_name);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO ocianalytics_readwrite', partition_name);
            created := created || partition_name || ', ';
        END IF;

        cur_date := (cur_date + INTERVAL '1 month')::DATE;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext('fcr_partition_lock'));

    IF created = '' THEN
        RETURN 'All partitions already exist.';
    END IF;
    RETURN 'Created: ' || rtrim(created, ', ');
END;
$$;


--
-- Name: fcr_ensure_partitions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fcr_ensure_partitions(months_ahead integer DEFAULT 6) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;
    start_date DATE;
    start_ts TIMESTAMPTZ;
    end_ts TIMESTAMPTZ;
    partition_name TEXT;
    created TEXT := '';
BEGIN
    -- Advisory lock to prevent concurrent partition creation
    PERFORM pg_advisory_lock(hashtext('fcr_partition_lock'));

    FOR i IN -6..months_ahead LOOP
        start_date := date_trunc('month', CURRENT_DATE + (i || ' months')::INTERVAL)::DATE;
        start_ts := make_timestamptz(EXTRACT(YEAR FROM start_date)::INT, EXTRACT(MONTH FROM start_date)::INT, 1, 0, 0, 0, 'UTC');
        end_ts := make_timestamptz(EXTRACT(YEAR FROM (start_date + INTERVAL '1 month'))::INT, EXTRACT(MONTH FROM (start_date + INTERVAL '1 month'))::INT, 1, 0, 0, 0, 'UTC');
        partition_name := 'focus_data_table_' || to_char(start_date, 'YYYY_MM');

        IF to_regclass('public.' || partition_name) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF focus_data_table FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_ts, end_ts
            );
            -- Grant permissions on new partition
            EXECUTE format('GRANT SELECT ON %I TO ocianalytics_readonly', partition_name);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO ocianalytics_readwrite', partition_name);
            created := created || partition_name || ', ';
        END IF;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext('fcr_partition_lock'));

    IF created = '' THEN
        RETURN 'All partitions already exist.';
    END IF;
    RETURN 'Created: ' || rtrim(created, ', ');
END;
$$;


--
-- Name: ocr_backfill_partitions(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ocr_backfill_partitions(from_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_date DATE;
    start_ts TIMESTAMPTZ;
    end_ts TIMESTAMPTZ;
    partition_name TEXT;
    created TEXT := '';
BEGIN
    PERFORM pg_advisory_lock(hashtext('ocr_partition_lock'));

    cur_date := date_trunc('month', from_date)::DATE;
    WHILE cur_date <= date_trunc('month', CURRENT_DATE)::DATE LOOP
        start_ts := make_timestamptz(EXTRACT(YEAR FROM cur_date)::INT, EXTRACT(MONTH FROM cur_date)::INT, 1, 0, 0, 0, 'UTC');
        end_ts := make_timestamptz(EXTRACT(YEAR FROM (cur_date + INTERVAL '1 month'))::INT, EXTRACT(MONTH FROM (cur_date + INTERVAL '1 month'))::INT, 1, 0, 0, 0, 'UTC');
        partition_name := 'oci_cost_report_' || to_char(cur_date, 'YYYY_MM');

        IF to_regclass('public.' || partition_name) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF oci_cost_report FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_ts, end_ts
            );
            EXECUTE format('GRANT SELECT ON %I TO ocianalytics_readonly', partition_name);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO ocianalytics_readwrite', partition_name);
            created := created || partition_name || ', ';
        END IF;

        cur_date := (cur_date + INTERVAL '1 month')::DATE;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext('ocr_partition_lock'));

    IF created = '' THEN
        RETURN 'All partitions already exist.';
    END IF;
    RETURN 'Created: ' || rtrim(created, ', ');
END;
$$;


--
-- Name: ocr_ensure_partitions(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ocr_ensure_partitions(months_ahead integer DEFAULT 6) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;
    start_date DATE;
    start_ts TIMESTAMPTZ;
    end_ts TIMESTAMPTZ;
    partition_name TEXT;
    created TEXT := '';
BEGIN
    PERFORM pg_advisory_lock(hashtext('ocr_partition_lock'));

    FOR i IN -6..months_ahead LOOP
        start_date := date_trunc('month', CURRENT_DATE + (i || ' months')::INTERVAL)::DATE;
        start_ts := make_timestamptz(EXTRACT(YEAR FROM start_date)::INT, EXTRACT(MONTH FROM start_date)::INT, 1, 0, 0, 0, 'UTC');
        end_ts := make_timestamptz(EXTRACT(YEAR FROM (start_date + INTERVAL '1 month'))::INT, EXTRACT(MONTH FROM (start_date + INTERVAL '1 month'))::INT, 1, 0, 0, 0, 'UTC');
        partition_name := 'oci_cost_report_' || to_char(start_date, 'YYYY_MM');

        IF to_regclass('public.' || partition_name) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF oci_cost_report FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_ts, end_ts
            );
            EXECUTE format('GRANT SELECT ON %I TO ocianalytics_readonly', partition_name);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO ocianalytics_readwrite', partition_name);
            created := created || partition_name || ', ';
        END IF;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext('ocr_partition_lock'));

    IF created = '' THEN
        RETURN 'All partitions already exist.';
    END IF;
    RETURN 'Created: ' || rtrim(created, ', ');
END;
$$;


SET default_tablespace = '';

--
-- Name: focus_data_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
)
PARTITION BY RANGE (billingperiodstart);


SET default_table_access_method = heap;

--
-- Name: focus_data_table_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2025_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2025_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2025_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_05 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_06 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_07 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_08 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_09 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2026_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2026_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_05 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_06 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_07 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_08 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_09 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2027_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2027_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_05 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_06 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_07 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_08 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_09 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2028_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2028_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_05 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_06 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_07 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_08 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_09 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2029_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2029_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_05 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_06 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_07 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_08 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_09 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_10 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_11 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2030_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2030_12 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2031_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2031_01 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2031_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2031_02 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2031_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2031_03 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: focus_data_table_2031_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.focus_data_table_2031_04 (
    billingperiodstart timestamp with time zone NOT NULL,
    availabilityzone character varying(256),
    billedcost numeric(20,10),
    billingaccountid character varying(256),
    billingaccountname character varying(256),
    billingcurrency character varying(10),
    billingperiodend timestamp with time zone,
    chargecategory character varying(50),
    chargedescription character varying(1000),
    chargefrequency character varying(50),
    chargeperiodend timestamp with time zone,
    chargeperiodstart timestamp with time zone,
    chargesubcategory character varying(256),
    commitmentdiscountcategory character varying(256),
    commitmentdiscountid character varying(256),
    commitmentdiscountname character varying(256),
    commitmentdiscounttype character varying(256),
    effectivecost numeric(20,10),
    invoiceissuer character varying(256),
    listcost numeric(20,10),
    listunitprice numeric(20,10),
    pricingcategory character varying(256),
    pricingquantity numeric(20,10),
    pricingunit character varying(256),
    provider character varying(256),
    publisher character varying(256),
    region character varying(256),
    resourceid character varying(512),
    resourcename character varying(512),
    resourcetype character varying(256),
    servicecategory character varying(256),
    servicename character varying(256),
    skuid character varying(256),
    skupriceid character varying(256),
    subaccountid character varying(256),
    subaccountname character varying(256),
    tags jsonb,
    usagequantity numeric(20,10),
    usageunit character varying(256),
    oci_referencenumber character varying(256),
    oci_compartmentid character varying(256),
    oci_compartmentname character varying(256),
    oci_overageflag character varying(10),
    oci_unitpriceoverage numeric(20,10),
    oci_billedquantityoverage numeric(20,10),
    oci_costoverage numeric(20,10),
    oci_attributedusage numeric(20,10),
    oci_attributedcost numeric(20,10),
    oci_backreferencenumber character varying(256),
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
)
PARTITION BY RANGE (lineitem_intervalusagestart);


--
-- Name: oci_cost_report_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2025_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2025_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2025_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_05 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_06 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_07 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_08 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_09 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2026_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2026_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_05 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_06 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_07 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_08 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_09 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2027_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2027_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_05 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_06 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_07 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_08 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_09 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2028_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2028_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_05 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_06 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_07 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_08 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_09 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2029_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2029_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_05 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_06 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_07 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_08 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_09 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_10 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_11 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2030_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2030_12 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2031_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2031_01 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2031_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2031_02 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2031_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2031_03 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_2031_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oci_cost_report_2031_04 (
    lineitem_referenceno character varying(256) NOT NULL,
    lineitem_tenantid character varying(256),
    lineitem_intervalusagestart timestamp with time zone NOT NULL,
    lineitem_intervalusageend timestamp with time zone,
    product_service character varying(256),
    product_compartmentid character varying(256),
    product_compartmentname character varying(256),
    product_region character varying(256),
    product_availabilitydomain character varying(256),
    product_resourceid character varying(512),
    usage_billedquantity numeric(20,10),
    usage_billedquantityoverage numeric(20,10),
    cost_subscriptionid character varying(256),
    cost_productsku character varying(256),
    product_description character varying(1000),
    cost_unitprice numeric(20,10),
    cost_unitpriceoverage numeric(20,10),
    cost_mycost numeric(20,10),
    cost_mycostoverage numeric(20,10),
    cost_currencycode character varying(10),
    cost_billingunitreadable character varying(256),
    cost_skuunitdescription character varying(256),
    cost_overageflag character varying(10),
    lineitem_iscorrection character varying(10),
    lineitem_backreferenceno character varying(256),
    cost_attributedcost numeric(20,10),
    usage_attributedusage numeric(20,10),
    tags jsonb,
    source_filename character varying(512) NOT NULL,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'UTC'::text)
);


--
-- Name: oci_cost_report_effective; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.oci_cost_report_effective AS
 SELECT lineitem_referenceno,
    lineitem_tenantid,
    lineitem_intervalusagestart,
    lineitem_intervalusageend,
    product_service,
    product_compartmentid,
    product_compartmentname,
    product_region,
    product_availabilitydomain,
    product_resourceid,
    usage_billedquantity,
    usage_billedquantityoverage,
    cost_subscriptionid,
    cost_productsku,
    product_description,
    cost_unitprice,
    cost_unitpriceoverage,
    cost_mycost,
    cost_mycostoverage,
    cost_currencycode,
    cost_billingunitreadable,
    cost_skuunitdescription,
    cost_overageflag,
    lineitem_iscorrection,
    lineitem_backreferenceno,
    cost_attributedcost,
    usage_attributedusage,
    tags,
    source_filename,
    created_at
   FROM public.oci_cost_report r
  WHERE (NOT (EXISTS ( SELECT 1
           FROM public.oci_cost_report c
          WHERE (((c.lineitem_backreferenceno)::text = (r.lineitem_referenceno)::text) AND (c.lineitem_iscorrection IS NOT NULL) AND (c.lineitem_intervalusagestart = r.lineitem_intervalusagestart)))));


--
-- Name: focus_data_table_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


--
-- Name: focus_data_table_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


--
-- Name: focus_data_table_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: focus_data_table_2026_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_01 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-02-01 00:00:00+00');


--
-- Name: focus_data_table_2026_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_02 FOR VALUES FROM ('2026-02-01 00:00:00+00') TO ('2026-03-01 00:00:00+00');


--
-- Name: focus_data_table_2026_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_03 FOR VALUES FROM ('2026-03-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: focus_data_table_2026_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_04 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-05-01 00:00:00+00');


--
-- Name: focus_data_table_2026_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_05 FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');


--
-- Name: focus_data_table_2026_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_06 FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: focus_data_table_2026_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_07 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');


--
-- Name: focus_data_table_2026_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_08 FOR VALUES FROM ('2026-08-01 00:00:00+00') TO ('2026-09-01 00:00:00+00');


--
-- Name: focus_data_table_2026_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_09 FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: focus_data_table_2026_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');


--
-- Name: focus_data_table_2026_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');


--
-- Name: focus_data_table_2026_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: focus_data_table_2027_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_01 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2027-02-01 00:00:00+00');


--
-- Name: focus_data_table_2027_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_02 FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00');


--
-- Name: focus_data_table_2027_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_03 FOR VALUES FROM ('2027-03-01 00:00:00+00') TO ('2027-04-01 00:00:00+00');


--
-- Name: focus_data_table_2027_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_04 FOR VALUES FROM ('2027-04-01 00:00:00+00') TO ('2027-05-01 00:00:00+00');


--
-- Name: focus_data_table_2027_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_05 FOR VALUES FROM ('2027-05-01 00:00:00+00') TO ('2027-06-01 00:00:00+00');


--
-- Name: focus_data_table_2027_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_06 FOR VALUES FROM ('2027-06-01 00:00:00+00') TO ('2027-07-01 00:00:00+00');


--
-- Name: focus_data_table_2027_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_07 FOR VALUES FROM ('2027-07-01 00:00:00+00') TO ('2027-08-01 00:00:00+00');


--
-- Name: focus_data_table_2027_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_08 FOR VALUES FROM ('2027-08-01 00:00:00+00') TO ('2027-09-01 00:00:00+00');


--
-- Name: focus_data_table_2027_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_09 FOR VALUES FROM ('2027-09-01 00:00:00+00') TO ('2027-10-01 00:00:00+00');


--
-- Name: focus_data_table_2027_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_10 FOR VALUES FROM ('2027-10-01 00:00:00+00') TO ('2027-11-01 00:00:00+00');


--
-- Name: focus_data_table_2027_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_11 FOR VALUES FROM ('2027-11-01 00:00:00+00') TO ('2027-12-01 00:00:00+00');


--
-- Name: focus_data_table_2027_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2027_12 FOR VALUES FROM ('2027-12-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: focus_data_table_2028_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_01 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2028-02-01 00:00:00+00');


--
-- Name: focus_data_table_2028_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_02 FOR VALUES FROM ('2028-02-01 00:00:00+00') TO ('2028-03-01 00:00:00+00');


--
-- Name: focus_data_table_2028_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_03 FOR VALUES FROM ('2028-03-01 00:00:00+00') TO ('2028-04-01 00:00:00+00');


--
-- Name: focus_data_table_2028_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_04 FOR VALUES FROM ('2028-04-01 00:00:00+00') TO ('2028-05-01 00:00:00+00');


--
-- Name: focus_data_table_2028_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_05 FOR VALUES FROM ('2028-05-01 00:00:00+00') TO ('2028-06-01 00:00:00+00');


--
-- Name: focus_data_table_2028_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_06 FOR VALUES FROM ('2028-06-01 00:00:00+00') TO ('2028-07-01 00:00:00+00');


--
-- Name: focus_data_table_2028_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_07 FOR VALUES FROM ('2028-07-01 00:00:00+00') TO ('2028-08-01 00:00:00+00');


--
-- Name: focus_data_table_2028_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_08 FOR VALUES FROM ('2028-08-01 00:00:00+00') TO ('2028-09-01 00:00:00+00');


--
-- Name: focus_data_table_2028_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_09 FOR VALUES FROM ('2028-09-01 00:00:00+00') TO ('2028-10-01 00:00:00+00');


--
-- Name: focus_data_table_2028_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_10 FOR VALUES FROM ('2028-10-01 00:00:00+00') TO ('2028-11-01 00:00:00+00');


--
-- Name: focus_data_table_2028_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_11 FOR VALUES FROM ('2028-11-01 00:00:00+00') TO ('2028-12-01 00:00:00+00');


--
-- Name: focus_data_table_2028_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2028_12 FOR VALUES FROM ('2028-12-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: focus_data_table_2029_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_01 FOR VALUES FROM ('2029-01-01 00:00:00+00') TO ('2029-02-01 00:00:00+00');


--
-- Name: focus_data_table_2029_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_02 FOR VALUES FROM ('2029-02-01 00:00:00+00') TO ('2029-03-01 00:00:00+00');


--
-- Name: focus_data_table_2029_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_03 FOR VALUES FROM ('2029-03-01 00:00:00+00') TO ('2029-04-01 00:00:00+00');


--
-- Name: focus_data_table_2029_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_04 FOR VALUES FROM ('2029-04-01 00:00:00+00') TO ('2029-05-01 00:00:00+00');


--
-- Name: focus_data_table_2029_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_05 FOR VALUES FROM ('2029-05-01 00:00:00+00') TO ('2029-06-01 00:00:00+00');


--
-- Name: focus_data_table_2029_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_06 FOR VALUES FROM ('2029-06-01 00:00:00+00') TO ('2029-07-01 00:00:00+00');


--
-- Name: focus_data_table_2029_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_07 FOR VALUES FROM ('2029-07-01 00:00:00+00') TO ('2029-08-01 00:00:00+00');


--
-- Name: focus_data_table_2029_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_08 FOR VALUES FROM ('2029-08-01 00:00:00+00') TO ('2029-09-01 00:00:00+00');


--
-- Name: focus_data_table_2029_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_09 FOR VALUES FROM ('2029-09-01 00:00:00+00') TO ('2029-10-01 00:00:00+00');


--
-- Name: focus_data_table_2029_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_10 FOR VALUES FROM ('2029-10-01 00:00:00+00') TO ('2029-11-01 00:00:00+00');


--
-- Name: focus_data_table_2029_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_11 FOR VALUES FROM ('2029-11-01 00:00:00+00') TO ('2029-12-01 00:00:00+00');


--
-- Name: focus_data_table_2029_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2029_12 FOR VALUES FROM ('2029-12-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');


--
-- Name: focus_data_table_2030_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_01 FOR VALUES FROM ('2030-01-01 00:00:00+00') TO ('2030-02-01 00:00:00+00');


--
-- Name: focus_data_table_2030_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_02 FOR VALUES FROM ('2030-02-01 00:00:00+00') TO ('2030-03-01 00:00:00+00');


--
-- Name: focus_data_table_2030_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_03 FOR VALUES FROM ('2030-03-01 00:00:00+00') TO ('2030-04-01 00:00:00+00');


--
-- Name: focus_data_table_2030_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_04 FOR VALUES FROM ('2030-04-01 00:00:00+00') TO ('2030-05-01 00:00:00+00');


--
-- Name: focus_data_table_2030_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_05 FOR VALUES FROM ('2030-05-01 00:00:00+00') TO ('2030-06-01 00:00:00+00');


--
-- Name: focus_data_table_2030_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_06 FOR VALUES FROM ('2030-06-01 00:00:00+00') TO ('2030-07-01 00:00:00+00');


--
-- Name: focus_data_table_2030_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_07 FOR VALUES FROM ('2030-07-01 00:00:00+00') TO ('2030-08-01 00:00:00+00');


--
-- Name: focus_data_table_2030_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_08 FOR VALUES FROM ('2030-08-01 00:00:00+00') TO ('2030-09-01 00:00:00+00');


--
-- Name: focus_data_table_2030_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_09 FOR VALUES FROM ('2030-09-01 00:00:00+00') TO ('2030-10-01 00:00:00+00');


--
-- Name: focus_data_table_2030_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_10 FOR VALUES FROM ('2030-10-01 00:00:00+00') TO ('2030-11-01 00:00:00+00');


--
-- Name: focus_data_table_2030_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_11 FOR VALUES FROM ('2030-11-01 00:00:00+00') TO ('2030-12-01 00:00:00+00');


--
-- Name: focus_data_table_2030_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2030_12 FOR VALUES FROM ('2030-12-01 00:00:00+00') TO ('2031-01-01 00:00:00+00');


--
-- Name: focus_data_table_2031_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2031_01 FOR VALUES FROM ('2031-01-01 00:00:00+00') TO ('2031-02-01 00:00:00+00');


--
-- Name: focus_data_table_2031_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2031_02 FOR VALUES FROM ('2031-02-01 00:00:00+00') TO ('2031-03-01 00:00:00+00');


--
-- Name: focus_data_table_2031_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2031_03 FOR VALUES FROM ('2031-03-01 00:00:00+00') TO ('2031-04-01 00:00:00+00');


--
-- Name: focus_data_table_2031_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.focus_data_table ATTACH PARTITION public.focus_data_table_2031_04 FOR VALUES FROM ('2031-04-01 00:00:00+00') TO ('2031-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2025_10 FOR VALUES FROM ('2025-10-01 00:00:00+00') TO ('2025-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2025_11 FOR VALUES FROM ('2025-11-01 00:00:00+00') TO ('2025-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2025_12 FOR VALUES FROM ('2025-12-01 00:00:00+00') TO ('2026-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_01 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_02 FOR VALUES FROM ('2026-02-01 00:00:00+00') TO ('2026-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_03 FOR VALUES FROM ('2026-03-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_04 FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_05 FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_06 FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_07 FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_08 FOR VALUES FROM ('2026-08-01 00:00:00+00') TO ('2026-09-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_09 FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_10 FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_11 FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2026_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2026_12 FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_01 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2027-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_02 FOR VALUES FROM ('2027-02-01 00:00:00+00') TO ('2027-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_03 FOR VALUES FROM ('2027-03-01 00:00:00+00') TO ('2027-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_04 FOR VALUES FROM ('2027-04-01 00:00:00+00') TO ('2027-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_05 FOR VALUES FROM ('2027-05-01 00:00:00+00') TO ('2027-06-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_06 FOR VALUES FROM ('2027-06-01 00:00:00+00') TO ('2027-07-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_07 FOR VALUES FROM ('2027-07-01 00:00:00+00') TO ('2027-08-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_08 FOR VALUES FROM ('2027-08-01 00:00:00+00') TO ('2027-09-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_09 FOR VALUES FROM ('2027-09-01 00:00:00+00') TO ('2027-10-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_10 FOR VALUES FROM ('2027-10-01 00:00:00+00') TO ('2027-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_11 FOR VALUES FROM ('2027-11-01 00:00:00+00') TO ('2027-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2027_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2027_12 FOR VALUES FROM ('2027-12-01 00:00:00+00') TO ('2028-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_01 FOR VALUES FROM ('2028-01-01 00:00:00+00') TO ('2028-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_02 FOR VALUES FROM ('2028-02-01 00:00:00+00') TO ('2028-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_03 FOR VALUES FROM ('2028-03-01 00:00:00+00') TO ('2028-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_04 FOR VALUES FROM ('2028-04-01 00:00:00+00') TO ('2028-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_05 FOR VALUES FROM ('2028-05-01 00:00:00+00') TO ('2028-06-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_06 FOR VALUES FROM ('2028-06-01 00:00:00+00') TO ('2028-07-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_07 FOR VALUES FROM ('2028-07-01 00:00:00+00') TO ('2028-08-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_08 FOR VALUES FROM ('2028-08-01 00:00:00+00') TO ('2028-09-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_09 FOR VALUES FROM ('2028-09-01 00:00:00+00') TO ('2028-10-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_10 FOR VALUES FROM ('2028-10-01 00:00:00+00') TO ('2028-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_11 FOR VALUES FROM ('2028-11-01 00:00:00+00') TO ('2028-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2028_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2028_12 FOR VALUES FROM ('2028-12-01 00:00:00+00') TO ('2029-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_01 FOR VALUES FROM ('2029-01-01 00:00:00+00') TO ('2029-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_02 FOR VALUES FROM ('2029-02-01 00:00:00+00') TO ('2029-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_03 FOR VALUES FROM ('2029-03-01 00:00:00+00') TO ('2029-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_04 FOR VALUES FROM ('2029-04-01 00:00:00+00') TO ('2029-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_05 FOR VALUES FROM ('2029-05-01 00:00:00+00') TO ('2029-06-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_06 FOR VALUES FROM ('2029-06-01 00:00:00+00') TO ('2029-07-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_07 FOR VALUES FROM ('2029-07-01 00:00:00+00') TO ('2029-08-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_08 FOR VALUES FROM ('2029-08-01 00:00:00+00') TO ('2029-09-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_09 FOR VALUES FROM ('2029-09-01 00:00:00+00') TO ('2029-10-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_10 FOR VALUES FROM ('2029-10-01 00:00:00+00') TO ('2029-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_11 FOR VALUES FROM ('2029-11-01 00:00:00+00') TO ('2029-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2029_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2029_12 FOR VALUES FROM ('2029-12-01 00:00:00+00') TO ('2030-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_01 FOR VALUES FROM ('2030-01-01 00:00:00+00') TO ('2030-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_02 FOR VALUES FROM ('2030-02-01 00:00:00+00') TO ('2030-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_03 FOR VALUES FROM ('2030-03-01 00:00:00+00') TO ('2030-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_04 FOR VALUES FROM ('2030-04-01 00:00:00+00') TO ('2030-05-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_05 FOR VALUES FROM ('2030-05-01 00:00:00+00') TO ('2030-06-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_06 FOR VALUES FROM ('2030-06-01 00:00:00+00') TO ('2030-07-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_07 FOR VALUES FROM ('2030-07-01 00:00:00+00') TO ('2030-08-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_08 FOR VALUES FROM ('2030-08-01 00:00:00+00') TO ('2030-09-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_09 FOR VALUES FROM ('2030-09-01 00:00:00+00') TO ('2030-10-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_10 FOR VALUES FROM ('2030-10-01 00:00:00+00') TO ('2030-11-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_11 FOR VALUES FROM ('2030-11-01 00:00:00+00') TO ('2030-12-01 00:00:00+00');


--
-- Name: oci_cost_report_2030_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2030_12 FOR VALUES FROM ('2030-12-01 00:00:00+00') TO ('2031-01-01 00:00:00+00');


--
-- Name: oci_cost_report_2031_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2031_01 FOR VALUES FROM ('2031-01-01 00:00:00+00') TO ('2031-02-01 00:00:00+00');


--
-- Name: oci_cost_report_2031_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2031_02 FOR VALUES FROM ('2031-02-01 00:00:00+00') TO ('2031-03-01 00:00:00+00');


--
-- Name: oci_cost_report_2031_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2031_03 FOR VALUES FROM ('2031-03-01 00:00:00+00') TO ('2031-04-01 00:00:00+00');


--
-- Name: oci_cost_report_2031_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oci_cost_report ATTACH PARTITION public.oci_cost_report_2031_04 FOR VALUES FROM ('2031-04-01 00:00:00+00') TO ('2031-05-01 00:00:00+00');


--
-- Name: idx_fcr_compartment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fcr_compartment ON ONLY public.focus_data_table USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2025_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2025_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: idx_fcr_source_file; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fcr_source_file ON ONLY public.focus_data_table USING btree (source_filename);


--
-- Name: focus_data_table_2025_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_10_source_filename_idx ON public.focus_data_table_2025_10 USING btree (source_filename);


--
-- Name: idx_fcr_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fcr_tags ON ONLY public.focus_data_table USING gin (tags);


--
-- Name: focus_data_table_2025_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_10_tags_idx ON public.focus_data_table_2025_10 USING gin (tags);


--
-- Name: focus_data_table_2025_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2025_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2025_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_11_source_filename_idx ON public.focus_data_table_2025_11 USING btree (source_filename);


--
-- Name: focus_data_table_2025_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_11_tags_idx ON public.focus_data_table_2025_11 USING gin (tags);


--
-- Name: focus_data_table_2025_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2025_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2025_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_12_source_filename_idx ON public.focus_data_table_2025_12 USING btree (source_filename);


--
-- Name: focus_data_table_2025_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2025_12_tags_idx ON public.focus_data_table_2025_12 USING gin (tags);


--
-- Name: focus_data_table_2026_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_01_source_filename_idx ON public.focus_data_table_2026_01 USING btree (source_filename);


--
-- Name: focus_data_table_2026_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_01_tags_idx ON public.focus_data_table_2026_01 USING gin (tags);


--
-- Name: focus_data_table_2026_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_02_source_filename_idx ON public.focus_data_table_2026_02 USING btree (source_filename);


--
-- Name: focus_data_table_2026_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_02_tags_idx ON public.focus_data_table_2026_02 USING gin (tags);


--
-- Name: focus_data_table_2026_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_03_source_filename_idx ON public.focus_data_table_2026_03 USING btree (source_filename);


--
-- Name: focus_data_table_2026_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_03_tags_idx ON public.focus_data_table_2026_03 USING gin (tags);


--
-- Name: focus_data_table_2026_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_04_source_filename_idx ON public.focus_data_table_2026_04 USING btree (source_filename);


--
-- Name: focus_data_table_2026_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_04_tags_idx ON public.focus_data_table_2026_04 USING gin (tags);


--
-- Name: focus_data_table_2026_05_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_05_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_05 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_05_source_filename_idx ON public.focus_data_table_2026_05 USING btree (source_filename);


--
-- Name: focus_data_table_2026_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_05_tags_idx ON public.focus_data_table_2026_05 USING gin (tags);


--
-- Name: focus_data_table_2026_06_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_06_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_06 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_06_source_filename_idx ON public.focus_data_table_2026_06 USING btree (source_filename);


--
-- Name: focus_data_table_2026_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_06_tags_idx ON public.focus_data_table_2026_06 USING gin (tags);


--
-- Name: focus_data_table_2026_07_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_07_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_07 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_07_source_filename_idx ON public.focus_data_table_2026_07 USING btree (source_filename);


--
-- Name: focus_data_table_2026_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_07_tags_idx ON public.focus_data_table_2026_07 USING gin (tags);


--
-- Name: focus_data_table_2026_08_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_08_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_08 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_08_source_filename_idx ON public.focus_data_table_2026_08 USING btree (source_filename);


--
-- Name: focus_data_table_2026_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_08_tags_idx ON public.focus_data_table_2026_08 USING gin (tags);


--
-- Name: focus_data_table_2026_09_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_09_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_09 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_09_source_filename_idx ON public.focus_data_table_2026_09 USING btree (source_filename);


--
-- Name: focus_data_table_2026_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_09_tags_idx ON public.focus_data_table_2026_09 USING gin (tags);


--
-- Name: focus_data_table_2026_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_10_source_filename_idx ON public.focus_data_table_2026_10 USING btree (source_filename);


--
-- Name: focus_data_table_2026_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_10_tags_idx ON public.focus_data_table_2026_10 USING gin (tags);


--
-- Name: focus_data_table_2026_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_11_source_filename_idx ON public.focus_data_table_2026_11 USING btree (source_filename);


--
-- Name: focus_data_table_2026_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_11_tags_idx ON public.focus_data_table_2026_11 USING gin (tags);


--
-- Name: focus_data_table_2026_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2026_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2026_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_12_source_filename_idx ON public.focus_data_table_2026_12 USING btree (source_filename);


--
-- Name: focus_data_table_2026_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2026_12_tags_idx ON public.focus_data_table_2026_12 USING gin (tags);


--
-- Name: focus_data_table_2027_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_01_source_filename_idx ON public.focus_data_table_2027_01 USING btree (source_filename);


--
-- Name: focus_data_table_2027_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_01_tags_idx ON public.focus_data_table_2027_01 USING gin (tags);


--
-- Name: focus_data_table_2027_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_02_source_filename_idx ON public.focus_data_table_2027_02 USING btree (source_filename);


--
-- Name: focus_data_table_2027_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_02_tags_idx ON public.focus_data_table_2027_02 USING gin (tags);


--
-- Name: focus_data_table_2027_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_03_source_filename_idx ON public.focus_data_table_2027_03 USING btree (source_filename);


--
-- Name: focus_data_table_2027_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_03_tags_idx ON public.focus_data_table_2027_03 USING gin (tags);


--
-- Name: focus_data_table_2027_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_04_source_filename_idx ON public.focus_data_table_2027_04 USING btree (source_filename);


--
-- Name: focus_data_table_2027_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_04_tags_idx ON public.focus_data_table_2027_04 USING gin (tags);


--
-- Name: focus_data_table_2027_05_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_05_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_05 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_05_source_filename_idx ON public.focus_data_table_2027_05 USING btree (source_filename);


--
-- Name: focus_data_table_2027_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_05_tags_idx ON public.focus_data_table_2027_05 USING gin (tags);


--
-- Name: focus_data_table_2027_06_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_06_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_06 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_06_source_filename_idx ON public.focus_data_table_2027_06 USING btree (source_filename);


--
-- Name: focus_data_table_2027_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_06_tags_idx ON public.focus_data_table_2027_06 USING gin (tags);


--
-- Name: focus_data_table_2027_07_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_07_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_07 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_07_source_filename_idx ON public.focus_data_table_2027_07 USING btree (source_filename);


--
-- Name: focus_data_table_2027_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_07_tags_idx ON public.focus_data_table_2027_07 USING gin (tags);


--
-- Name: focus_data_table_2027_08_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_08_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_08 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_08_source_filename_idx ON public.focus_data_table_2027_08 USING btree (source_filename);


--
-- Name: focus_data_table_2027_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_08_tags_idx ON public.focus_data_table_2027_08 USING gin (tags);


--
-- Name: focus_data_table_2027_09_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_09_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_09 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_09_source_filename_idx ON public.focus_data_table_2027_09 USING btree (source_filename);


--
-- Name: focus_data_table_2027_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_09_tags_idx ON public.focus_data_table_2027_09 USING gin (tags);


--
-- Name: focus_data_table_2027_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_10_source_filename_idx ON public.focus_data_table_2027_10 USING btree (source_filename);


--
-- Name: focus_data_table_2027_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_10_tags_idx ON public.focus_data_table_2027_10 USING gin (tags);


--
-- Name: focus_data_table_2027_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_11_source_filename_idx ON public.focus_data_table_2027_11 USING btree (source_filename);


--
-- Name: focus_data_table_2027_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_11_tags_idx ON public.focus_data_table_2027_11 USING gin (tags);


--
-- Name: focus_data_table_2027_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2027_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2027_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_12_source_filename_idx ON public.focus_data_table_2027_12 USING btree (source_filename);


--
-- Name: focus_data_table_2027_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2027_12_tags_idx ON public.focus_data_table_2027_12 USING gin (tags);


--
-- Name: focus_data_table_2028_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_01_source_filename_idx ON public.focus_data_table_2028_01 USING btree (source_filename);


--
-- Name: focus_data_table_2028_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_01_tags_idx ON public.focus_data_table_2028_01 USING gin (tags);


--
-- Name: focus_data_table_2028_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_02_source_filename_idx ON public.focus_data_table_2028_02 USING btree (source_filename);


--
-- Name: focus_data_table_2028_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_02_tags_idx ON public.focus_data_table_2028_02 USING gin (tags);


--
-- Name: focus_data_table_2028_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_03_source_filename_idx ON public.focus_data_table_2028_03 USING btree (source_filename);


--
-- Name: focus_data_table_2028_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_03_tags_idx ON public.focus_data_table_2028_03 USING gin (tags);


--
-- Name: focus_data_table_2028_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_04_source_filename_idx ON public.focus_data_table_2028_04 USING btree (source_filename);


--
-- Name: focus_data_table_2028_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_04_tags_idx ON public.focus_data_table_2028_04 USING gin (tags);


--
-- Name: focus_data_table_2028_05_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_05_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_05 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_05_source_filename_idx ON public.focus_data_table_2028_05 USING btree (source_filename);


--
-- Name: focus_data_table_2028_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_05_tags_idx ON public.focus_data_table_2028_05 USING gin (tags);


--
-- Name: focus_data_table_2028_06_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_06_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_06 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_06_source_filename_idx ON public.focus_data_table_2028_06 USING btree (source_filename);


--
-- Name: focus_data_table_2028_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_06_tags_idx ON public.focus_data_table_2028_06 USING gin (tags);


--
-- Name: focus_data_table_2028_07_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_07_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_07 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_07_source_filename_idx ON public.focus_data_table_2028_07 USING btree (source_filename);


--
-- Name: focus_data_table_2028_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_07_tags_idx ON public.focus_data_table_2028_07 USING gin (tags);


--
-- Name: focus_data_table_2028_08_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_08_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_08 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_08_source_filename_idx ON public.focus_data_table_2028_08 USING btree (source_filename);


--
-- Name: focus_data_table_2028_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_08_tags_idx ON public.focus_data_table_2028_08 USING gin (tags);


--
-- Name: focus_data_table_2028_09_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_09_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_09 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_09_source_filename_idx ON public.focus_data_table_2028_09 USING btree (source_filename);


--
-- Name: focus_data_table_2028_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_09_tags_idx ON public.focus_data_table_2028_09 USING gin (tags);


--
-- Name: focus_data_table_2028_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_10_source_filename_idx ON public.focus_data_table_2028_10 USING btree (source_filename);


--
-- Name: focus_data_table_2028_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_10_tags_idx ON public.focus_data_table_2028_10 USING gin (tags);


--
-- Name: focus_data_table_2028_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_11_source_filename_idx ON public.focus_data_table_2028_11 USING btree (source_filename);


--
-- Name: focus_data_table_2028_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_11_tags_idx ON public.focus_data_table_2028_11 USING gin (tags);


--
-- Name: focus_data_table_2028_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2028_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2028_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_12_source_filename_idx ON public.focus_data_table_2028_12 USING btree (source_filename);


--
-- Name: focus_data_table_2028_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2028_12_tags_idx ON public.focus_data_table_2028_12 USING gin (tags);


--
-- Name: focus_data_table_2029_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_01_source_filename_idx ON public.focus_data_table_2029_01 USING btree (source_filename);


--
-- Name: focus_data_table_2029_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_01_tags_idx ON public.focus_data_table_2029_01 USING gin (tags);


--
-- Name: focus_data_table_2029_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_02_source_filename_idx ON public.focus_data_table_2029_02 USING btree (source_filename);


--
-- Name: focus_data_table_2029_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_02_tags_idx ON public.focus_data_table_2029_02 USING gin (tags);


--
-- Name: focus_data_table_2029_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_03_source_filename_idx ON public.focus_data_table_2029_03 USING btree (source_filename);


--
-- Name: focus_data_table_2029_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_03_tags_idx ON public.focus_data_table_2029_03 USING gin (tags);


--
-- Name: focus_data_table_2029_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_04_source_filename_idx ON public.focus_data_table_2029_04 USING btree (source_filename);


--
-- Name: focus_data_table_2029_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_04_tags_idx ON public.focus_data_table_2029_04 USING gin (tags);


--
-- Name: focus_data_table_2029_05_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_05_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_05 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_05_source_filename_idx ON public.focus_data_table_2029_05 USING btree (source_filename);


--
-- Name: focus_data_table_2029_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_05_tags_idx ON public.focus_data_table_2029_05 USING gin (tags);


--
-- Name: focus_data_table_2029_06_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_06_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_06 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_06_source_filename_idx ON public.focus_data_table_2029_06 USING btree (source_filename);


--
-- Name: focus_data_table_2029_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_06_tags_idx ON public.focus_data_table_2029_06 USING gin (tags);


--
-- Name: focus_data_table_2029_07_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_07_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_07 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_07_source_filename_idx ON public.focus_data_table_2029_07 USING btree (source_filename);


--
-- Name: focus_data_table_2029_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_07_tags_idx ON public.focus_data_table_2029_07 USING gin (tags);


--
-- Name: focus_data_table_2029_08_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_08_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_08 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_08_source_filename_idx ON public.focus_data_table_2029_08 USING btree (source_filename);


--
-- Name: focus_data_table_2029_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_08_tags_idx ON public.focus_data_table_2029_08 USING gin (tags);


--
-- Name: focus_data_table_2029_09_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_09_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_09 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_09_source_filename_idx ON public.focus_data_table_2029_09 USING btree (source_filename);


--
-- Name: focus_data_table_2029_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_09_tags_idx ON public.focus_data_table_2029_09 USING gin (tags);


--
-- Name: focus_data_table_2029_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_10_source_filename_idx ON public.focus_data_table_2029_10 USING btree (source_filename);


--
-- Name: focus_data_table_2029_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_10_tags_idx ON public.focus_data_table_2029_10 USING gin (tags);


--
-- Name: focus_data_table_2029_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_11_source_filename_idx ON public.focus_data_table_2029_11 USING btree (source_filename);


--
-- Name: focus_data_table_2029_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_11_tags_idx ON public.focus_data_table_2029_11 USING gin (tags);


--
-- Name: focus_data_table_2029_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2029_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2029_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_12_source_filename_idx ON public.focus_data_table_2029_12 USING btree (source_filename);


--
-- Name: focus_data_table_2029_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2029_12_tags_idx ON public.focus_data_table_2029_12 USING gin (tags);


--
-- Name: focus_data_table_2030_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_01_source_filename_idx ON public.focus_data_table_2030_01 USING btree (source_filename);


--
-- Name: focus_data_table_2030_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_01_tags_idx ON public.focus_data_table_2030_01 USING gin (tags);


--
-- Name: focus_data_table_2030_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_02_source_filename_idx ON public.focus_data_table_2030_02 USING btree (source_filename);


--
-- Name: focus_data_table_2030_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_02_tags_idx ON public.focus_data_table_2030_02 USING gin (tags);


--
-- Name: focus_data_table_2030_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_03_source_filename_idx ON public.focus_data_table_2030_03 USING btree (source_filename);


--
-- Name: focus_data_table_2030_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_03_tags_idx ON public.focus_data_table_2030_03 USING gin (tags);


--
-- Name: focus_data_table_2030_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_04_source_filename_idx ON public.focus_data_table_2030_04 USING btree (source_filename);


--
-- Name: focus_data_table_2030_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_04_tags_idx ON public.focus_data_table_2030_04 USING gin (tags);


--
-- Name: focus_data_table_2030_05_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_05_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_05 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_05_source_filename_idx ON public.focus_data_table_2030_05 USING btree (source_filename);


--
-- Name: focus_data_table_2030_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_05_tags_idx ON public.focus_data_table_2030_05 USING gin (tags);


--
-- Name: focus_data_table_2030_06_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_06_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_06 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_06_source_filename_idx ON public.focus_data_table_2030_06 USING btree (source_filename);


--
-- Name: focus_data_table_2030_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_06_tags_idx ON public.focus_data_table_2030_06 USING gin (tags);


--
-- Name: focus_data_table_2030_07_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_07_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_07 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_07_source_filename_idx ON public.focus_data_table_2030_07 USING btree (source_filename);


--
-- Name: focus_data_table_2030_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_07_tags_idx ON public.focus_data_table_2030_07 USING gin (tags);


--
-- Name: focus_data_table_2030_08_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_08_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_08 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_08_source_filename_idx ON public.focus_data_table_2030_08 USING btree (source_filename);


--
-- Name: focus_data_table_2030_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_08_tags_idx ON public.focus_data_table_2030_08 USING gin (tags);


--
-- Name: focus_data_table_2030_09_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_09_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_09 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_09_source_filename_idx ON public.focus_data_table_2030_09 USING btree (source_filename);


--
-- Name: focus_data_table_2030_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_09_tags_idx ON public.focus_data_table_2030_09 USING gin (tags);


--
-- Name: focus_data_table_2030_10_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_10_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_10 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_10_source_filename_idx ON public.focus_data_table_2030_10 USING btree (source_filename);


--
-- Name: focus_data_table_2030_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_10_tags_idx ON public.focus_data_table_2030_10 USING gin (tags);


--
-- Name: focus_data_table_2030_11_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_11_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_11 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_11_source_filename_idx ON public.focus_data_table_2030_11 USING btree (source_filename);


--
-- Name: focus_data_table_2030_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_11_tags_idx ON public.focus_data_table_2030_11 USING gin (tags);


--
-- Name: focus_data_table_2030_12_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_12_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2030_12 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2030_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_12_source_filename_idx ON public.focus_data_table_2030_12 USING btree (source_filename);


--
-- Name: focus_data_table_2030_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2030_12_tags_idx ON public.focus_data_table_2030_12 USING gin (tags);


--
-- Name: focus_data_table_2031_01_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_01_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2031_01 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2031_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_01_source_filename_idx ON public.focus_data_table_2031_01 USING btree (source_filename);


--
-- Name: focus_data_table_2031_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_01_tags_idx ON public.focus_data_table_2031_01 USING gin (tags);


--
-- Name: focus_data_table_2031_02_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_02_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2031_02 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2031_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_02_source_filename_idx ON public.focus_data_table_2031_02 USING btree (source_filename);


--
-- Name: focus_data_table_2031_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_02_tags_idx ON public.focus_data_table_2031_02 USING gin (tags);


--
-- Name: focus_data_table_2031_03_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_03_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2031_03 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2031_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_03_source_filename_idx ON public.focus_data_table_2031_03 USING btree (source_filename);


--
-- Name: focus_data_table_2031_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_03_tags_idx ON public.focus_data_table_2031_03 USING gin (tags);


--
-- Name: focus_data_table_2031_04_oci_compartmentname_servicecategor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_04_oci_compartmentname_servicecategor_idx ON public.focus_data_table_2031_04 USING btree (oci_compartmentname, servicecategory, resourcetype);


--
-- Name: focus_data_table_2031_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_04_source_filename_idx ON public.focus_data_table_2031_04 USING btree (source_filename);


--
-- Name: focus_data_table_2031_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX focus_data_table_2031_04_tags_idx ON public.focus_data_table_2031_04 USING gin (tags);


--
-- Name: idx_ocr_backreference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_backreference ON ONLY public.oci_cost_report USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: idx_ocr_compartment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_compartment ON ONLY public.oci_cost_report USING btree (product_compartmentname);


--
-- Name: idx_ocr_compartment1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_compartment1 ON ONLY public.oci_cost_report USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: idx_ocr_correction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_correction ON ONLY public.oci_cost_report USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: idx_ocr_referenceno; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_referenceno ON ONLY public.oci_cost_report USING btree (lineitem_referenceno);


--
-- Name: idx_ocr_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_resource ON ONLY public.oci_cost_report USING btree (product_resourceid);


--
-- Name: idx_ocr_source_file; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_source_file ON ONLY public.oci_cost_report USING btree (source_filename);


--
-- Name: idx_ocr_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_tags ON ONLY public.oci_cost_report USING gin (tags);


--
-- Name: idx_ocr_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ocr_tenant ON ONLY public.oci_cost_report USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2025_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2025_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2025_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_lineitem_iscorrection_idx ON public.oci_cost_report_2025_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2025_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_lineitem_referenceno_idx ON public.oci_cost_report_2025_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2025_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_lineitem_tenantid_idx ON public.oci_cost_report_2025_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2025_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_product_compartmentname_idx ON public.oci_cost_report_2025_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2025_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2025_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2025_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_product_resourceid_idx ON public.oci_cost_report_2025_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2025_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_source_filename_idx ON public.oci_cost_report_2025_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2025_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_10_tags_idx ON public.oci_cost_report_2025_10 USING gin (tags);


--
-- Name: oci_cost_report_2025_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2025_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2025_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_lineitem_iscorrection_idx ON public.oci_cost_report_2025_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2025_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_lineitem_referenceno_idx ON public.oci_cost_report_2025_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2025_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_lineitem_tenantid_idx ON public.oci_cost_report_2025_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2025_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_product_compartmentname_idx ON public.oci_cost_report_2025_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2025_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2025_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2025_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_product_resourceid_idx ON public.oci_cost_report_2025_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2025_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_source_filename_idx ON public.oci_cost_report_2025_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2025_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_11_tags_idx ON public.oci_cost_report_2025_11 USING gin (tags);


--
-- Name: oci_cost_report_2025_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2025_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2025_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_lineitem_iscorrection_idx ON public.oci_cost_report_2025_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2025_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_lineitem_referenceno_idx ON public.oci_cost_report_2025_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2025_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_lineitem_tenantid_idx ON public.oci_cost_report_2025_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2025_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_product_compartmentname_idx ON public.oci_cost_report_2025_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2025_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2025_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2025_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_product_resourceid_idx ON public.oci_cost_report_2025_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2025_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_source_filename_idx ON public.oci_cost_report_2025_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2025_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2025_12_tags_idx ON public.oci_cost_report_2025_12 USING gin (tags);


--
-- Name: oci_cost_report_2026_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_lineitem_iscorrection_idx ON public.oci_cost_report_2026_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_lineitem_referenceno_idx ON public.oci_cost_report_2026_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_lineitem_tenantid_idx ON public.oci_cost_report_2026_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_product_compartmentname_idx ON public.oci_cost_report_2026_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_product_resourceid_idx ON public.oci_cost_report_2026_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_source_filename_idx ON public.oci_cost_report_2026_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_01_tags_idx ON public.oci_cost_report_2026_01 USING gin (tags);


--
-- Name: oci_cost_report_2026_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_lineitem_iscorrection_idx ON public.oci_cost_report_2026_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_lineitem_referenceno_idx ON public.oci_cost_report_2026_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_lineitem_tenantid_idx ON public.oci_cost_report_2026_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_product_compartmentname_idx ON public.oci_cost_report_2026_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_product_resourceid_idx ON public.oci_cost_report_2026_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_source_filename_idx ON public.oci_cost_report_2026_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_02_tags_idx ON public.oci_cost_report_2026_02 USING gin (tags);


--
-- Name: oci_cost_report_2026_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_lineitem_iscorrection_idx ON public.oci_cost_report_2026_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_lineitem_referenceno_idx ON public.oci_cost_report_2026_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_lineitem_tenantid_idx ON public.oci_cost_report_2026_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_product_compartmentname_idx ON public.oci_cost_report_2026_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_product_resourceid_idx ON public.oci_cost_report_2026_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_source_filename_idx ON public.oci_cost_report_2026_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_03_tags_idx ON public.oci_cost_report_2026_03 USING gin (tags);


--
-- Name: oci_cost_report_2026_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_lineitem_iscorrection_idx ON public.oci_cost_report_2026_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_lineitem_referenceno_idx ON public.oci_cost_report_2026_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_lineitem_tenantid_idx ON public.oci_cost_report_2026_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_product_compartmentname_idx ON public.oci_cost_report_2026_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_product_resourceid_idx ON public.oci_cost_report_2026_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_source_filename_idx ON public.oci_cost_report_2026_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_04_tags_idx ON public.oci_cost_report_2026_04 USING gin (tags);


--
-- Name: oci_cost_report_2026_05_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_05 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_05_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_lineitem_iscorrection_idx ON public.oci_cost_report_2026_05 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_05_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_lineitem_referenceno_idx ON public.oci_cost_report_2026_05 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_05_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_lineitem_tenantid_idx ON public.oci_cost_report_2026_05 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_05_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_product_compartmentname_idx ON public.oci_cost_report_2026_05 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_05_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_05 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_05_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_product_resourceid_idx ON public.oci_cost_report_2026_05 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_source_filename_idx ON public.oci_cost_report_2026_05 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_05_tags_idx ON public.oci_cost_report_2026_05 USING gin (tags);


--
-- Name: oci_cost_report_2026_06_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_06 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_06_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_lineitem_iscorrection_idx ON public.oci_cost_report_2026_06 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_06_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_lineitem_referenceno_idx ON public.oci_cost_report_2026_06 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_06_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_lineitem_tenantid_idx ON public.oci_cost_report_2026_06 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_06_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_product_compartmentname_idx ON public.oci_cost_report_2026_06 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_06_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_06 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_06_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_product_resourceid_idx ON public.oci_cost_report_2026_06 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_source_filename_idx ON public.oci_cost_report_2026_06 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_06_tags_idx ON public.oci_cost_report_2026_06 USING gin (tags);


--
-- Name: oci_cost_report_2026_07_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_07 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_07_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_lineitem_iscorrection_idx ON public.oci_cost_report_2026_07 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_07_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_lineitem_referenceno_idx ON public.oci_cost_report_2026_07 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_07_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_lineitem_tenantid_idx ON public.oci_cost_report_2026_07 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_07_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_product_compartmentname_idx ON public.oci_cost_report_2026_07 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_07_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_07 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_07_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_product_resourceid_idx ON public.oci_cost_report_2026_07 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_source_filename_idx ON public.oci_cost_report_2026_07 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_07_tags_idx ON public.oci_cost_report_2026_07 USING gin (tags);


--
-- Name: oci_cost_report_2026_08_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_08 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_08_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_lineitem_iscorrection_idx ON public.oci_cost_report_2026_08 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_08_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_lineitem_referenceno_idx ON public.oci_cost_report_2026_08 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_08_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_lineitem_tenantid_idx ON public.oci_cost_report_2026_08 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_08_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_product_compartmentname_idx ON public.oci_cost_report_2026_08 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_08_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_08 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_08_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_product_resourceid_idx ON public.oci_cost_report_2026_08 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_source_filename_idx ON public.oci_cost_report_2026_08 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_08_tags_idx ON public.oci_cost_report_2026_08 USING gin (tags);


--
-- Name: oci_cost_report_2026_09_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_09 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_09_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_lineitem_iscorrection_idx ON public.oci_cost_report_2026_09 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_09_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_lineitem_referenceno_idx ON public.oci_cost_report_2026_09 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_09_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_lineitem_tenantid_idx ON public.oci_cost_report_2026_09 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_09_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_product_compartmentname_idx ON public.oci_cost_report_2026_09 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_09_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_09 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_09_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_product_resourceid_idx ON public.oci_cost_report_2026_09 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_source_filename_idx ON public.oci_cost_report_2026_09 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_09_tags_idx ON public.oci_cost_report_2026_09 USING gin (tags);


--
-- Name: oci_cost_report_2026_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_lineitem_iscorrection_idx ON public.oci_cost_report_2026_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_lineitem_referenceno_idx ON public.oci_cost_report_2026_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_lineitem_tenantid_idx ON public.oci_cost_report_2026_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_product_compartmentname_idx ON public.oci_cost_report_2026_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_product_resourceid_idx ON public.oci_cost_report_2026_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_source_filename_idx ON public.oci_cost_report_2026_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_10_tags_idx ON public.oci_cost_report_2026_10 USING gin (tags);


--
-- Name: oci_cost_report_2026_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_lineitem_iscorrection_idx ON public.oci_cost_report_2026_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_lineitem_referenceno_idx ON public.oci_cost_report_2026_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_lineitem_tenantid_idx ON public.oci_cost_report_2026_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_product_compartmentname_idx ON public.oci_cost_report_2026_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_product_resourceid_idx ON public.oci_cost_report_2026_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_source_filename_idx ON public.oci_cost_report_2026_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_11_tags_idx ON public.oci_cost_report_2026_11 USING gin (tags);


--
-- Name: oci_cost_report_2026_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2026_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2026_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_lineitem_iscorrection_idx ON public.oci_cost_report_2026_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2026_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_lineitem_referenceno_idx ON public.oci_cost_report_2026_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2026_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_lineitem_tenantid_idx ON public.oci_cost_report_2026_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2026_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_product_compartmentname_idx ON public.oci_cost_report_2026_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2026_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2026_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2026_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_product_resourceid_idx ON public.oci_cost_report_2026_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2026_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_source_filename_idx ON public.oci_cost_report_2026_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2026_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2026_12_tags_idx ON public.oci_cost_report_2026_12 USING gin (tags);


--
-- Name: oci_cost_report_2027_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_lineitem_iscorrection_idx ON public.oci_cost_report_2027_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_lineitem_referenceno_idx ON public.oci_cost_report_2027_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_lineitem_tenantid_idx ON public.oci_cost_report_2027_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_product_compartmentname_idx ON public.oci_cost_report_2027_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_product_resourceid_idx ON public.oci_cost_report_2027_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_source_filename_idx ON public.oci_cost_report_2027_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_01_tags_idx ON public.oci_cost_report_2027_01 USING gin (tags);


--
-- Name: oci_cost_report_2027_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_lineitem_iscorrection_idx ON public.oci_cost_report_2027_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_lineitem_referenceno_idx ON public.oci_cost_report_2027_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_lineitem_tenantid_idx ON public.oci_cost_report_2027_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_product_compartmentname_idx ON public.oci_cost_report_2027_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_product_resourceid_idx ON public.oci_cost_report_2027_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_source_filename_idx ON public.oci_cost_report_2027_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_02_tags_idx ON public.oci_cost_report_2027_02 USING gin (tags);


--
-- Name: oci_cost_report_2027_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_lineitem_iscorrection_idx ON public.oci_cost_report_2027_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_lineitem_referenceno_idx ON public.oci_cost_report_2027_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_lineitem_tenantid_idx ON public.oci_cost_report_2027_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_product_compartmentname_idx ON public.oci_cost_report_2027_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_product_resourceid_idx ON public.oci_cost_report_2027_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_source_filename_idx ON public.oci_cost_report_2027_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_03_tags_idx ON public.oci_cost_report_2027_03 USING gin (tags);


--
-- Name: oci_cost_report_2027_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_lineitem_iscorrection_idx ON public.oci_cost_report_2027_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_lineitem_referenceno_idx ON public.oci_cost_report_2027_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_lineitem_tenantid_idx ON public.oci_cost_report_2027_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_product_compartmentname_idx ON public.oci_cost_report_2027_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_product_resourceid_idx ON public.oci_cost_report_2027_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_source_filename_idx ON public.oci_cost_report_2027_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_04_tags_idx ON public.oci_cost_report_2027_04 USING gin (tags);


--
-- Name: oci_cost_report_2027_05_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_05 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_05_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_lineitem_iscorrection_idx ON public.oci_cost_report_2027_05 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_05_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_lineitem_referenceno_idx ON public.oci_cost_report_2027_05 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_05_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_lineitem_tenantid_idx ON public.oci_cost_report_2027_05 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_05_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_product_compartmentname_idx ON public.oci_cost_report_2027_05 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_05_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_05 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_05_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_product_resourceid_idx ON public.oci_cost_report_2027_05 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_source_filename_idx ON public.oci_cost_report_2027_05 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_05_tags_idx ON public.oci_cost_report_2027_05 USING gin (tags);


--
-- Name: oci_cost_report_2027_06_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_06 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_06_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_lineitem_iscorrection_idx ON public.oci_cost_report_2027_06 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_06_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_lineitem_referenceno_idx ON public.oci_cost_report_2027_06 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_06_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_lineitem_tenantid_idx ON public.oci_cost_report_2027_06 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_06_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_product_compartmentname_idx ON public.oci_cost_report_2027_06 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_06_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_06 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_06_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_product_resourceid_idx ON public.oci_cost_report_2027_06 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_source_filename_idx ON public.oci_cost_report_2027_06 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_06_tags_idx ON public.oci_cost_report_2027_06 USING gin (tags);


--
-- Name: oci_cost_report_2027_07_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_07 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_07_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_lineitem_iscorrection_idx ON public.oci_cost_report_2027_07 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_07_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_lineitem_referenceno_idx ON public.oci_cost_report_2027_07 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_07_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_lineitem_tenantid_idx ON public.oci_cost_report_2027_07 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_07_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_product_compartmentname_idx ON public.oci_cost_report_2027_07 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_07_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_07 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_07_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_product_resourceid_idx ON public.oci_cost_report_2027_07 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_source_filename_idx ON public.oci_cost_report_2027_07 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_07_tags_idx ON public.oci_cost_report_2027_07 USING gin (tags);


--
-- Name: oci_cost_report_2027_08_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_08 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_08_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_lineitem_iscorrection_idx ON public.oci_cost_report_2027_08 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_08_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_lineitem_referenceno_idx ON public.oci_cost_report_2027_08 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_08_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_lineitem_tenantid_idx ON public.oci_cost_report_2027_08 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_08_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_product_compartmentname_idx ON public.oci_cost_report_2027_08 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_08_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_08 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_08_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_product_resourceid_idx ON public.oci_cost_report_2027_08 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_source_filename_idx ON public.oci_cost_report_2027_08 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_08_tags_idx ON public.oci_cost_report_2027_08 USING gin (tags);


--
-- Name: oci_cost_report_2027_09_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_09 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_09_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_lineitem_iscorrection_idx ON public.oci_cost_report_2027_09 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_09_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_lineitem_referenceno_idx ON public.oci_cost_report_2027_09 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_09_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_lineitem_tenantid_idx ON public.oci_cost_report_2027_09 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_09_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_product_compartmentname_idx ON public.oci_cost_report_2027_09 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_09_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_09 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_09_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_product_resourceid_idx ON public.oci_cost_report_2027_09 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_source_filename_idx ON public.oci_cost_report_2027_09 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_09_tags_idx ON public.oci_cost_report_2027_09 USING gin (tags);


--
-- Name: oci_cost_report_2027_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_lineitem_iscorrection_idx ON public.oci_cost_report_2027_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_lineitem_referenceno_idx ON public.oci_cost_report_2027_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_lineitem_tenantid_idx ON public.oci_cost_report_2027_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_product_compartmentname_idx ON public.oci_cost_report_2027_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_product_resourceid_idx ON public.oci_cost_report_2027_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_source_filename_idx ON public.oci_cost_report_2027_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_10_tags_idx ON public.oci_cost_report_2027_10 USING gin (tags);


--
-- Name: oci_cost_report_2027_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_lineitem_iscorrection_idx ON public.oci_cost_report_2027_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_lineitem_referenceno_idx ON public.oci_cost_report_2027_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_lineitem_tenantid_idx ON public.oci_cost_report_2027_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_product_compartmentname_idx ON public.oci_cost_report_2027_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_product_resourceid_idx ON public.oci_cost_report_2027_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_source_filename_idx ON public.oci_cost_report_2027_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_11_tags_idx ON public.oci_cost_report_2027_11 USING gin (tags);


--
-- Name: oci_cost_report_2027_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2027_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2027_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_lineitem_iscorrection_idx ON public.oci_cost_report_2027_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2027_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_lineitem_referenceno_idx ON public.oci_cost_report_2027_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2027_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_lineitem_tenantid_idx ON public.oci_cost_report_2027_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2027_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_product_compartmentname_idx ON public.oci_cost_report_2027_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2027_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2027_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2027_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_product_resourceid_idx ON public.oci_cost_report_2027_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2027_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_source_filename_idx ON public.oci_cost_report_2027_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2027_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2027_12_tags_idx ON public.oci_cost_report_2027_12 USING gin (tags);


--
-- Name: oci_cost_report_2028_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_lineitem_iscorrection_idx ON public.oci_cost_report_2028_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_lineitem_referenceno_idx ON public.oci_cost_report_2028_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_lineitem_tenantid_idx ON public.oci_cost_report_2028_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_product_compartmentname_idx ON public.oci_cost_report_2028_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_product_resourceid_idx ON public.oci_cost_report_2028_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_source_filename_idx ON public.oci_cost_report_2028_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_01_tags_idx ON public.oci_cost_report_2028_01 USING gin (tags);


--
-- Name: oci_cost_report_2028_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_lineitem_iscorrection_idx ON public.oci_cost_report_2028_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_lineitem_referenceno_idx ON public.oci_cost_report_2028_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_lineitem_tenantid_idx ON public.oci_cost_report_2028_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_product_compartmentname_idx ON public.oci_cost_report_2028_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_product_resourceid_idx ON public.oci_cost_report_2028_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_source_filename_idx ON public.oci_cost_report_2028_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_02_tags_idx ON public.oci_cost_report_2028_02 USING gin (tags);


--
-- Name: oci_cost_report_2028_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_lineitem_iscorrection_idx ON public.oci_cost_report_2028_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_lineitem_referenceno_idx ON public.oci_cost_report_2028_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_lineitem_tenantid_idx ON public.oci_cost_report_2028_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_product_compartmentname_idx ON public.oci_cost_report_2028_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_product_resourceid_idx ON public.oci_cost_report_2028_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_source_filename_idx ON public.oci_cost_report_2028_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_03_tags_idx ON public.oci_cost_report_2028_03 USING gin (tags);


--
-- Name: oci_cost_report_2028_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_lineitem_iscorrection_idx ON public.oci_cost_report_2028_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_lineitem_referenceno_idx ON public.oci_cost_report_2028_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_lineitem_tenantid_idx ON public.oci_cost_report_2028_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_product_compartmentname_idx ON public.oci_cost_report_2028_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_product_resourceid_idx ON public.oci_cost_report_2028_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_source_filename_idx ON public.oci_cost_report_2028_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_04_tags_idx ON public.oci_cost_report_2028_04 USING gin (tags);


--
-- Name: oci_cost_report_2028_05_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_05 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_05_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_lineitem_iscorrection_idx ON public.oci_cost_report_2028_05 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_05_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_lineitem_referenceno_idx ON public.oci_cost_report_2028_05 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_05_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_lineitem_tenantid_idx ON public.oci_cost_report_2028_05 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_05_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_product_compartmentname_idx ON public.oci_cost_report_2028_05 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_05_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_05 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_05_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_product_resourceid_idx ON public.oci_cost_report_2028_05 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_source_filename_idx ON public.oci_cost_report_2028_05 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_05_tags_idx ON public.oci_cost_report_2028_05 USING gin (tags);


--
-- Name: oci_cost_report_2028_06_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_06 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_06_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_lineitem_iscorrection_idx ON public.oci_cost_report_2028_06 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_06_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_lineitem_referenceno_idx ON public.oci_cost_report_2028_06 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_06_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_lineitem_tenantid_idx ON public.oci_cost_report_2028_06 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_06_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_product_compartmentname_idx ON public.oci_cost_report_2028_06 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_06_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_06 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_06_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_product_resourceid_idx ON public.oci_cost_report_2028_06 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_source_filename_idx ON public.oci_cost_report_2028_06 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_06_tags_idx ON public.oci_cost_report_2028_06 USING gin (tags);


--
-- Name: oci_cost_report_2028_07_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_07 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_07_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_lineitem_iscorrection_idx ON public.oci_cost_report_2028_07 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_07_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_lineitem_referenceno_idx ON public.oci_cost_report_2028_07 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_07_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_lineitem_tenantid_idx ON public.oci_cost_report_2028_07 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_07_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_product_compartmentname_idx ON public.oci_cost_report_2028_07 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_07_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_07 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_07_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_product_resourceid_idx ON public.oci_cost_report_2028_07 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_source_filename_idx ON public.oci_cost_report_2028_07 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_07_tags_idx ON public.oci_cost_report_2028_07 USING gin (tags);


--
-- Name: oci_cost_report_2028_08_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_08 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_08_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_lineitem_iscorrection_idx ON public.oci_cost_report_2028_08 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_08_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_lineitem_referenceno_idx ON public.oci_cost_report_2028_08 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_08_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_lineitem_tenantid_idx ON public.oci_cost_report_2028_08 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_08_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_product_compartmentname_idx ON public.oci_cost_report_2028_08 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_08_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_08 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_08_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_product_resourceid_idx ON public.oci_cost_report_2028_08 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_source_filename_idx ON public.oci_cost_report_2028_08 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_08_tags_idx ON public.oci_cost_report_2028_08 USING gin (tags);


--
-- Name: oci_cost_report_2028_09_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_09 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_09_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_lineitem_iscorrection_idx ON public.oci_cost_report_2028_09 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_09_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_lineitem_referenceno_idx ON public.oci_cost_report_2028_09 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_09_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_lineitem_tenantid_idx ON public.oci_cost_report_2028_09 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_09_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_product_compartmentname_idx ON public.oci_cost_report_2028_09 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_09_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_09 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_09_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_product_resourceid_idx ON public.oci_cost_report_2028_09 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_source_filename_idx ON public.oci_cost_report_2028_09 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_09_tags_idx ON public.oci_cost_report_2028_09 USING gin (tags);


--
-- Name: oci_cost_report_2028_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_lineitem_iscorrection_idx ON public.oci_cost_report_2028_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_lineitem_referenceno_idx ON public.oci_cost_report_2028_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_lineitem_tenantid_idx ON public.oci_cost_report_2028_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_product_compartmentname_idx ON public.oci_cost_report_2028_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_product_resourceid_idx ON public.oci_cost_report_2028_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_source_filename_idx ON public.oci_cost_report_2028_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_10_tags_idx ON public.oci_cost_report_2028_10 USING gin (tags);


--
-- Name: oci_cost_report_2028_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_lineitem_iscorrection_idx ON public.oci_cost_report_2028_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_lineitem_referenceno_idx ON public.oci_cost_report_2028_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_lineitem_tenantid_idx ON public.oci_cost_report_2028_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_product_compartmentname_idx ON public.oci_cost_report_2028_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_product_resourceid_idx ON public.oci_cost_report_2028_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_source_filename_idx ON public.oci_cost_report_2028_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_11_tags_idx ON public.oci_cost_report_2028_11 USING gin (tags);


--
-- Name: oci_cost_report_2028_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2028_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2028_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_lineitem_iscorrection_idx ON public.oci_cost_report_2028_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2028_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_lineitem_referenceno_idx ON public.oci_cost_report_2028_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2028_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_lineitem_tenantid_idx ON public.oci_cost_report_2028_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2028_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_product_compartmentname_idx ON public.oci_cost_report_2028_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2028_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2028_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2028_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_product_resourceid_idx ON public.oci_cost_report_2028_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2028_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_source_filename_idx ON public.oci_cost_report_2028_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2028_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2028_12_tags_idx ON public.oci_cost_report_2028_12 USING gin (tags);


--
-- Name: oci_cost_report_2029_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_lineitem_iscorrection_idx ON public.oci_cost_report_2029_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_lineitem_referenceno_idx ON public.oci_cost_report_2029_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_lineitem_tenantid_idx ON public.oci_cost_report_2029_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_product_compartmentname_idx ON public.oci_cost_report_2029_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_product_resourceid_idx ON public.oci_cost_report_2029_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_source_filename_idx ON public.oci_cost_report_2029_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_01_tags_idx ON public.oci_cost_report_2029_01 USING gin (tags);


--
-- Name: oci_cost_report_2029_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_lineitem_iscorrection_idx ON public.oci_cost_report_2029_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_lineitem_referenceno_idx ON public.oci_cost_report_2029_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_lineitem_tenantid_idx ON public.oci_cost_report_2029_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_product_compartmentname_idx ON public.oci_cost_report_2029_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_product_resourceid_idx ON public.oci_cost_report_2029_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_source_filename_idx ON public.oci_cost_report_2029_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_02_tags_idx ON public.oci_cost_report_2029_02 USING gin (tags);


--
-- Name: oci_cost_report_2029_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_lineitem_iscorrection_idx ON public.oci_cost_report_2029_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_lineitem_referenceno_idx ON public.oci_cost_report_2029_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_lineitem_tenantid_idx ON public.oci_cost_report_2029_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_product_compartmentname_idx ON public.oci_cost_report_2029_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_product_resourceid_idx ON public.oci_cost_report_2029_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_source_filename_idx ON public.oci_cost_report_2029_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_03_tags_idx ON public.oci_cost_report_2029_03 USING gin (tags);


--
-- Name: oci_cost_report_2029_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_lineitem_iscorrection_idx ON public.oci_cost_report_2029_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_lineitem_referenceno_idx ON public.oci_cost_report_2029_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_lineitem_tenantid_idx ON public.oci_cost_report_2029_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_product_compartmentname_idx ON public.oci_cost_report_2029_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_product_resourceid_idx ON public.oci_cost_report_2029_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_source_filename_idx ON public.oci_cost_report_2029_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_04_tags_idx ON public.oci_cost_report_2029_04 USING gin (tags);


--
-- Name: oci_cost_report_2029_05_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_05 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_05_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_lineitem_iscorrection_idx ON public.oci_cost_report_2029_05 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_05_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_lineitem_referenceno_idx ON public.oci_cost_report_2029_05 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_05_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_lineitem_tenantid_idx ON public.oci_cost_report_2029_05 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_05_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_product_compartmentname_idx ON public.oci_cost_report_2029_05 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_05_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_05 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_05_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_product_resourceid_idx ON public.oci_cost_report_2029_05 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_source_filename_idx ON public.oci_cost_report_2029_05 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_05_tags_idx ON public.oci_cost_report_2029_05 USING gin (tags);


--
-- Name: oci_cost_report_2029_06_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_06 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_06_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_lineitem_iscorrection_idx ON public.oci_cost_report_2029_06 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_06_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_lineitem_referenceno_idx ON public.oci_cost_report_2029_06 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_06_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_lineitem_tenantid_idx ON public.oci_cost_report_2029_06 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_06_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_product_compartmentname_idx ON public.oci_cost_report_2029_06 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_06_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_06 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_06_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_product_resourceid_idx ON public.oci_cost_report_2029_06 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_source_filename_idx ON public.oci_cost_report_2029_06 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_06_tags_idx ON public.oci_cost_report_2029_06 USING gin (tags);


--
-- Name: oci_cost_report_2029_07_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_07 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_07_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_lineitem_iscorrection_idx ON public.oci_cost_report_2029_07 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_07_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_lineitem_referenceno_idx ON public.oci_cost_report_2029_07 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_07_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_lineitem_tenantid_idx ON public.oci_cost_report_2029_07 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_07_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_product_compartmentname_idx ON public.oci_cost_report_2029_07 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_07_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_07 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_07_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_product_resourceid_idx ON public.oci_cost_report_2029_07 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_source_filename_idx ON public.oci_cost_report_2029_07 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_07_tags_idx ON public.oci_cost_report_2029_07 USING gin (tags);


--
-- Name: oci_cost_report_2029_08_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_08 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_08_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_lineitem_iscorrection_idx ON public.oci_cost_report_2029_08 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_08_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_lineitem_referenceno_idx ON public.oci_cost_report_2029_08 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_08_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_lineitem_tenantid_idx ON public.oci_cost_report_2029_08 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_08_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_product_compartmentname_idx ON public.oci_cost_report_2029_08 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_08_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_08 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_08_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_product_resourceid_idx ON public.oci_cost_report_2029_08 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_source_filename_idx ON public.oci_cost_report_2029_08 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_08_tags_idx ON public.oci_cost_report_2029_08 USING gin (tags);


--
-- Name: oci_cost_report_2029_09_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_09 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_09_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_lineitem_iscorrection_idx ON public.oci_cost_report_2029_09 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_09_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_lineitem_referenceno_idx ON public.oci_cost_report_2029_09 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_09_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_lineitem_tenantid_idx ON public.oci_cost_report_2029_09 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_09_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_product_compartmentname_idx ON public.oci_cost_report_2029_09 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_09_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_09 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_09_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_product_resourceid_idx ON public.oci_cost_report_2029_09 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_source_filename_idx ON public.oci_cost_report_2029_09 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_09_tags_idx ON public.oci_cost_report_2029_09 USING gin (tags);


--
-- Name: oci_cost_report_2029_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_lineitem_iscorrection_idx ON public.oci_cost_report_2029_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_lineitem_referenceno_idx ON public.oci_cost_report_2029_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_lineitem_tenantid_idx ON public.oci_cost_report_2029_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_product_compartmentname_idx ON public.oci_cost_report_2029_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_product_resourceid_idx ON public.oci_cost_report_2029_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_source_filename_idx ON public.oci_cost_report_2029_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_10_tags_idx ON public.oci_cost_report_2029_10 USING gin (tags);


--
-- Name: oci_cost_report_2029_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_lineitem_iscorrection_idx ON public.oci_cost_report_2029_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_lineitem_referenceno_idx ON public.oci_cost_report_2029_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_lineitem_tenantid_idx ON public.oci_cost_report_2029_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_product_compartmentname_idx ON public.oci_cost_report_2029_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_product_resourceid_idx ON public.oci_cost_report_2029_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_source_filename_idx ON public.oci_cost_report_2029_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_11_tags_idx ON public.oci_cost_report_2029_11 USING gin (tags);


--
-- Name: oci_cost_report_2029_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2029_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2029_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_lineitem_iscorrection_idx ON public.oci_cost_report_2029_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2029_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_lineitem_referenceno_idx ON public.oci_cost_report_2029_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2029_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_lineitem_tenantid_idx ON public.oci_cost_report_2029_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2029_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_product_compartmentname_idx ON public.oci_cost_report_2029_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2029_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2029_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2029_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_product_resourceid_idx ON public.oci_cost_report_2029_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2029_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_source_filename_idx ON public.oci_cost_report_2029_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2029_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2029_12_tags_idx ON public.oci_cost_report_2029_12 USING gin (tags);


--
-- Name: oci_cost_report_2030_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_lineitem_iscorrection_idx ON public.oci_cost_report_2030_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_lineitem_referenceno_idx ON public.oci_cost_report_2030_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_lineitem_tenantid_idx ON public.oci_cost_report_2030_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_product_compartmentname_idx ON public.oci_cost_report_2030_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_product_resourceid_idx ON public.oci_cost_report_2030_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_source_filename_idx ON public.oci_cost_report_2030_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_01_tags_idx ON public.oci_cost_report_2030_01 USING gin (tags);


--
-- Name: oci_cost_report_2030_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_lineitem_iscorrection_idx ON public.oci_cost_report_2030_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_lineitem_referenceno_idx ON public.oci_cost_report_2030_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_lineitem_tenantid_idx ON public.oci_cost_report_2030_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_product_compartmentname_idx ON public.oci_cost_report_2030_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_product_resourceid_idx ON public.oci_cost_report_2030_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_source_filename_idx ON public.oci_cost_report_2030_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_02_tags_idx ON public.oci_cost_report_2030_02 USING gin (tags);


--
-- Name: oci_cost_report_2030_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_lineitem_iscorrection_idx ON public.oci_cost_report_2030_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_lineitem_referenceno_idx ON public.oci_cost_report_2030_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_lineitem_tenantid_idx ON public.oci_cost_report_2030_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_product_compartmentname_idx ON public.oci_cost_report_2030_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_product_resourceid_idx ON public.oci_cost_report_2030_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_source_filename_idx ON public.oci_cost_report_2030_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_03_tags_idx ON public.oci_cost_report_2030_03 USING gin (tags);


--
-- Name: oci_cost_report_2030_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_lineitem_iscorrection_idx ON public.oci_cost_report_2030_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_lineitem_referenceno_idx ON public.oci_cost_report_2030_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_lineitem_tenantid_idx ON public.oci_cost_report_2030_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_product_compartmentname_idx ON public.oci_cost_report_2030_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_product_resourceid_idx ON public.oci_cost_report_2030_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_source_filename_idx ON public.oci_cost_report_2030_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_04_tags_idx ON public.oci_cost_report_2030_04 USING gin (tags);


--
-- Name: oci_cost_report_2030_05_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_05 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_05_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_lineitem_iscorrection_idx ON public.oci_cost_report_2030_05 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_05_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_lineitem_referenceno_idx ON public.oci_cost_report_2030_05 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_05_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_lineitem_tenantid_idx ON public.oci_cost_report_2030_05 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_05_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_product_compartmentname_idx ON public.oci_cost_report_2030_05 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_05_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_05 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_05_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_product_resourceid_idx ON public.oci_cost_report_2030_05 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_05_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_source_filename_idx ON public.oci_cost_report_2030_05 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_05_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_05_tags_idx ON public.oci_cost_report_2030_05 USING gin (tags);


--
-- Name: oci_cost_report_2030_06_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_06 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_06_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_lineitem_iscorrection_idx ON public.oci_cost_report_2030_06 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_06_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_lineitem_referenceno_idx ON public.oci_cost_report_2030_06 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_06_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_lineitem_tenantid_idx ON public.oci_cost_report_2030_06 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_06_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_product_compartmentname_idx ON public.oci_cost_report_2030_06 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_06_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_06 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_06_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_product_resourceid_idx ON public.oci_cost_report_2030_06 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_06_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_source_filename_idx ON public.oci_cost_report_2030_06 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_06_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_06_tags_idx ON public.oci_cost_report_2030_06 USING gin (tags);


--
-- Name: oci_cost_report_2030_07_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_07 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_07_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_lineitem_iscorrection_idx ON public.oci_cost_report_2030_07 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_07_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_lineitem_referenceno_idx ON public.oci_cost_report_2030_07 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_07_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_lineitem_tenantid_idx ON public.oci_cost_report_2030_07 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_07_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_product_compartmentname_idx ON public.oci_cost_report_2030_07 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_07_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_07 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_07_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_product_resourceid_idx ON public.oci_cost_report_2030_07 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_07_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_source_filename_idx ON public.oci_cost_report_2030_07 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_07_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_07_tags_idx ON public.oci_cost_report_2030_07 USING gin (tags);


--
-- Name: oci_cost_report_2030_08_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_08 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_08_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_lineitem_iscorrection_idx ON public.oci_cost_report_2030_08 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_08_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_lineitem_referenceno_idx ON public.oci_cost_report_2030_08 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_08_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_lineitem_tenantid_idx ON public.oci_cost_report_2030_08 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_08_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_product_compartmentname_idx ON public.oci_cost_report_2030_08 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_08_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_08 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_08_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_product_resourceid_idx ON public.oci_cost_report_2030_08 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_08_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_source_filename_idx ON public.oci_cost_report_2030_08 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_08_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_08_tags_idx ON public.oci_cost_report_2030_08 USING gin (tags);


--
-- Name: oci_cost_report_2030_09_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_09 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_09_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_lineitem_iscorrection_idx ON public.oci_cost_report_2030_09 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_09_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_lineitem_referenceno_idx ON public.oci_cost_report_2030_09 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_09_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_lineitem_tenantid_idx ON public.oci_cost_report_2030_09 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_09_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_product_compartmentname_idx ON public.oci_cost_report_2030_09 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_09_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_09 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_09_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_product_resourceid_idx ON public.oci_cost_report_2030_09 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_09_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_source_filename_idx ON public.oci_cost_report_2030_09 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_09_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_09_tags_idx ON public.oci_cost_report_2030_09 USING gin (tags);


--
-- Name: oci_cost_report_2030_10_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_10 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_10_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_lineitem_iscorrection_idx ON public.oci_cost_report_2030_10 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_10_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_lineitem_referenceno_idx ON public.oci_cost_report_2030_10 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_10_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_lineitem_tenantid_idx ON public.oci_cost_report_2030_10 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_10_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_product_compartmentname_idx ON public.oci_cost_report_2030_10 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_10_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_10 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_10_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_product_resourceid_idx ON public.oci_cost_report_2030_10 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_10_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_source_filename_idx ON public.oci_cost_report_2030_10 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_10_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_10_tags_idx ON public.oci_cost_report_2030_10 USING gin (tags);


--
-- Name: oci_cost_report_2030_11_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_11 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_11_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_lineitem_iscorrection_idx ON public.oci_cost_report_2030_11 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_11_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_lineitem_referenceno_idx ON public.oci_cost_report_2030_11 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_11_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_lineitem_tenantid_idx ON public.oci_cost_report_2030_11 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_11_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_product_compartmentname_idx ON public.oci_cost_report_2030_11 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_11_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_11 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_11_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_product_resourceid_idx ON public.oci_cost_report_2030_11 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_11_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_source_filename_idx ON public.oci_cost_report_2030_11 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_11_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_11_tags_idx ON public.oci_cost_report_2030_11 USING gin (tags);


--
-- Name: oci_cost_report_2030_12_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_lineitem_backreferenceno_idx ON public.oci_cost_report_2030_12 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2030_12_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_lineitem_iscorrection_idx ON public.oci_cost_report_2030_12 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2030_12_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_lineitem_referenceno_idx ON public.oci_cost_report_2030_12 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2030_12_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_lineitem_tenantid_idx ON public.oci_cost_report_2030_12 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2030_12_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_product_compartmentname_idx ON public.oci_cost_report_2030_12 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2030_12_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_product_region_product_compartmentn_idx ON public.oci_cost_report_2030_12 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2030_12_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_product_resourceid_idx ON public.oci_cost_report_2030_12 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2030_12_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_source_filename_idx ON public.oci_cost_report_2030_12 USING btree (source_filename);


--
-- Name: oci_cost_report_2030_12_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2030_12_tags_idx ON public.oci_cost_report_2030_12 USING gin (tags);


--
-- Name: oci_cost_report_2031_01_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_lineitem_backreferenceno_idx ON public.oci_cost_report_2031_01 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2031_01_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_lineitem_iscorrection_idx ON public.oci_cost_report_2031_01 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2031_01_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_lineitem_referenceno_idx ON public.oci_cost_report_2031_01 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2031_01_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_lineitem_tenantid_idx ON public.oci_cost_report_2031_01 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2031_01_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_product_compartmentname_idx ON public.oci_cost_report_2031_01 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2031_01_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_product_region_product_compartmentn_idx ON public.oci_cost_report_2031_01 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2031_01_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_product_resourceid_idx ON public.oci_cost_report_2031_01 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2031_01_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_source_filename_idx ON public.oci_cost_report_2031_01 USING btree (source_filename);


--
-- Name: oci_cost_report_2031_01_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_01_tags_idx ON public.oci_cost_report_2031_01 USING gin (tags);


--
-- Name: oci_cost_report_2031_02_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_lineitem_backreferenceno_idx ON public.oci_cost_report_2031_02 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2031_02_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_lineitem_iscorrection_idx ON public.oci_cost_report_2031_02 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2031_02_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_lineitem_referenceno_idx ON public.oci_cost_report_2031_02 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2031_02_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_lineitem_tenantid_idx ON public.oci_cost_report_2031_02 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2031_02_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_product_compartmentname_idx ON public.oci_cost_report_2031_02 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2031_02_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_product_region_product_compartmentn_idx ON public.oci_cost_report_2031_02 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2031_02_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_product_resourceid_idx ON public.oci_cost_report_2031_02 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2031_02_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_source_filename_idx ON public.oci_cost_report_2031_02 USING btree (source_filename);


--
-- Name: oci_cost_report_2031_02_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_02_tags_idx ON public.oci_cost_report_2031_02 USING gin (tags);


--
-- Name: oci_cost_report_2031_03_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_lineitem_backreferenceno_idx ON public.oci_cost_report_2031_03 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2031_03_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_lineitem_iscorrection_idx ON public.oci_cost_report_2031_03 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2031_03_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_lineitem_referenceno_idx ON public.oci_cost_report_2031_03 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2031_03_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_lineitem_tenantid_idx ON public.oci_cost_report_2031_03 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2031_03_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_product_compartmentname_idx ON public.oci_cost_report_2031_03 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2031_03_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_product_region_product_compartmentn_idx ON public.oci_cost_report_2031_03 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2031_03_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_product_resourceid_idx ON public.oci_cost_report_2031_03 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2031_03_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_source_filename_idx ON public.oci_cost_report_2031_03 USING btree (source_filename);


--
-- Name: oci_cost_report_2031_03_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_03_tags_idx ON public.oci_cost_report_2031_03 USING gin (tags);


--
-- Name: oci_cost_report_2031_04_lineitem_backreferenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_lineitem_backreferenceno_idx ON public.oci_cost_report_2031_04 USING btree (lineitem_backreferenceno) WHERE (lineitem_backreferenceno IS NOT NULL);


--
-- Name: oci_cost_report_2031_04_lineitem_iscorrection_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_lineitem_iscorrection_idx ON public.oci_cost_report_2031_04 USING btree (lineitem_iscorrection) WHERE (lineitem_iscorrection IS NOT NULL);


--
-- Name: oci_cost_report_2031_04_lineitem_referenceno_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_lineitem_referenceno_idx ON public.oci_cost_report_2031_04 USING btree (lineitem_referenceno);


--
-- Name: oci_cost_report_2031_04_lineitem_tenantid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_lineitem_tenantid_idx ON public.oci_cost_report_2031_04 USING btree (lineitem_tenantid);


--
-- Name: oci_cost_report_2031_04_product_compartmentname_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_product_compartmentname_idx ON public.oci_cost_report_2031_04 USING btree (product_compartmentname);


--
-- Name: oci_cost_report_2031_04_product_region_product_compartmentn_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_product_region_product_compartmentn_idx ON public.oci_cost_report_2031_04 USING btree (product_region, product_compartmentname, product_service, product_description);


--
-- Name: oci_cost_report_2031_04_product_resourceid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_product_resourceid_idx ON public.oci_cost_report_2031_04 USING btree (product_resourceid);


--
-- Name: oci_cost_report_2031_04_source_filename_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_source_filename_idx ON public.oci_cost_report_2031_04 USING btree (source_filename);


--
-- Name: oci_cost_report_2031_04_tags_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oci_cost_report_2031_04_tags_idx ON public.oci_cost_report_2031_04 USING gin (tags);


--
-- Name: focus_data_table_2025_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2025_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2025_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2025_10_source_filename_idx;


--
-- Name: focus_data_table_2025_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2025_10_tags_idx;


--
-- Name: focus_data_table_2025_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2025_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2025_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2025_11_source_filename_idx;


--
-- Name: focus_data_table_2025_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2025_11_tags_idx;


--
-- Name: focus_data_table_2025_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2025_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2025_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2025_12_source_filename_idx;


--
-- Name: focus_data_table_2025_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2025_12_tags_idx;


--
-- Name: focus_data_table_2026_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_01_source_filename_idx;


--
-- Name: focus_data_table_2026_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_01_tags_idx;


--
-- Name: focus_data_table_2026_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_02_source_filename_idx;


--
-- Name: focus_data_table_2026_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_02_tags_idx;


--
-- Name: focus_data_table_2026_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_03_source_filename_idx;


--
-- Name: focus_data_table_2026_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_03_tags_idx;


--
-- Name: focus_data_table_2026_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_04_source_filename_idx;


--
-- Name: focus_data_table_2026_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_04_tags_idx;


--
-- Name: focus_data_table_2026_05_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_05_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_05_source_filename_idx;


--
-- Name: focus_data_table_2026_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_05_tags_idx;


--
-- Name: focus_data_table_2026_06_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_06_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_06_source_filename_idx;


--
-- Name: focus_data_table_2026_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_06_tags_idx;


--
-- Name: focus_data_table_2026_07_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_07_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_07_source_filename_idx;


--
-- Name: focus_data_table_2026_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_07_tags_idx;


--
-- Name: focus_data_table_2026_08_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_08_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_08_source_filename_idx;


--
-- Name: focus_data_table_2026_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_08_tags_idx;


--
-- Name: focus_data_table_2026_09_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_09_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_09_source_filename_idx;


--
-- Name: focus_data_table_2026_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_09_tags_idx;


--
-- Name: focus_data_table_2026_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_10_source_filename_idx;


--
-- Name: focus_data_table_2026_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_10_tags_idx;


--
-- Name: focus_data_table_2026_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_11_source_filename_idx;


--
-- Name: focus_data_table_2026_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_11_tags_idx;


--
-- Name: focus_data_table_2026_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2026_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2026_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2026_12_source_filename_idx;


--
-- Name: focus_data_table_2026_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2026_12_tags_idx;


--
-- Name: focus_data_table_2027_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_01_source_filename_idx;


--
-- Name: focus_data_table_2027_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_01_tags_idx;


--
-- Name: focus_data_table_2027_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_02_source_filename_idx;


--
-- Name: focus_data_table_2027_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_02_tags_idx;


--
-- Name: focus_data_table_2027_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_03_source_filename_idx;


--
-- Name: focus_data_table_2027_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_03_tags_idx;


--
-- Name: focus_data_table_2027_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_04_source_filename_idx;


--
-- Name: focus_data_table_2027_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_04_tags_idx;


--
-- Name: focus_data_table_2027_05_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_05_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_05_source_filename_idx;


--
-- Name: focus_data_table_2027_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_05_tags_idx;


--
-- Name: focus_data_table_2027_06_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_06_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_06_source_filename_idx;


--
-- Name: focus_data_table_2027_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_06_tags_idx;


--
-- Name: focus_data_table_2027_07_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_07_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_07_source_filename_idx;


--
-- Name: focus_data_table_2027_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_07_tags_idx;


--
-- Name: focus_data_table_2027_08_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_08_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_08_source_filename_idx;


--
-- Name: focus_data_table_2027_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_08_tags_idx;


--
-- Name: focus_data_table_2027_09_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_09_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_09_source_filename_idx;


--
-- Name: focus_data_table_2027_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_09_tags_idx;


--
-- Name: focus_data_table_2027_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_10_source_filename_idx;


--
-- Name: focus_data_table_2027_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_10_tags_idx;


--
-- Name: focus_data_table_2027_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_11_source_filename_idx;


--
-- Name: focus_data_table_2027_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_11_tags_idx;


--
-- Name: focus_data_table_2027_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2027_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2027_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2027_12_source_filename_idx;


--
-- Name: focus_data_table_2027_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2027_12_tags_idx;


--
-- Name: focus_data_table_2028_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_01_source_filename_idx;


--
-- Name: focus_data_table_2028_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_01_tags_idx;


--
-- Name: focus_data_table_2028_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_02_source_filename_idx;


--
-- Name: focus_data_table_2028_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_02_tags_idx;


--
-- Name: focus_data_table_2028_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_03_source_filename_idx;


--
-- Name: focus_data_table_2028_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_03_tags_idx;


--
-- Name: focus_data_table_2028_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_04_source_filename_idx;


--
-- Name: focus_data_table_2028_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_04_tags_idx;


--
-- Name: focus_data_table_2028_05_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_05_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_05_source_filename_idx;


--
-- Name: focus_data_table_2028_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_05_tags_idx;


--
-- Name: focus_data_table_2028_06_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_06_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_06_source_filename_idx;


--
-- Name: focus_data_table_2028_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_06_tags_idx;


--
-- Name: focus_data_table_2028_07_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_07_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_07_source_filename_idx;


--
-- Name: focus_data_table_2028_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_07_tags_idx;


--
-- Name: focus_data_table_2028_08_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_08_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_08_source_filename_idx;


--
-- Name: focus_data_table_2028_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_08_tags_idx;


--
-- Name: focus_data_table_2028_09_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_09_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_09_source_filename_idx;


--
-- Name: focus_data_table_2028_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_09_tags_idx;


--
-- Name: focus_data_table_2028_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_10_source_filename_idx;


--
-- Name: focus_data_table_2028_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_10_tags_idx;


--
-- Name: focus_data_table_2028_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_11_source_filename_idx;


--
-- Name: focus_data_table_2028_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_11_tags_idx;


--
-- Name: focus_data_table_2028_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2028_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2028_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2028_12_source_filename_idx;


--
-- Name: focus_data_table_2028_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2028_12_tags_idx;


--
-- Name: focus_data_table_2029_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_01_source_filename_idx;


--
-- Name: focus_data_table_2029_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_01_tags_idx;


--
-- Name: focus_data_table_2029_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_02_source_filename_idx;


--
-- Name: focus_data_table_2029_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_02_tags_idx;


--
-- Name: focus_data_table_2029_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_03_source_filename_idx;


--
-- Name: focus_data_table_2029_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_03_tags_idx;


--
-- Name: focus_data_table_2029_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_04_source_filename_idx;


--
-- Name: focus_data_table_2029_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_04_tags_idx;


--
-- Name: focus_data_table_2029_05_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_05_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_05_source_filename_idx;


--
-- Name: focus_data_table_2029_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_05_tags_idx;


--
-- Name: focus_data_table_2029_06_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_06_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_06_source_filename_idx;


--
-- Name: focus_data_table_2029_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_06_tags_idx;


--
-- Name: focus_data_table_2029_07_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_07_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_07_source_filename_idx;


--
-- Name: focus_data_table_2029_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_07_tags_idx;


--
-- Name: focus_data_table_2029_08_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_08_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_08_source_filename_idx;


--
-- Name: focus_data_table_2029_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_08_tags_idx;


--
-- Name: focus_data_table_2029_09_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_09_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_09_source_filename_idx;


--
-- Name: focus_data_table_2029_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_09_tags_idx;


--
-- Name: focus_data_table_2029_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_10_source_filename_idx;


--
-- Name: focus_data_table_2029_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_10_tags_idx;


--
-- Name: focus_data_table_2029_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_11_source_filename_idx;


--
-- Name: focus_data_table_2029_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_11_tags_idx;


--
-- Name: focus_data_table_2029_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2029_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2029_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2029_12_source_filename_idx;


--
-- Name: focus_data_table_2029_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2029_12_tags_idx;


--
-- Name: focus_data_table_2030_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_01_source_filename_idx;


--
-- Name: focus_data_table_2030_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_01_tags_idx;


--
-- Name: focus_data_table_2030_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_02_source_filename_idx;


--
-- Name: focus_data_table_2030_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_02_tags_idx;


--
-- Name: focus_data_table_2030_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_03_source_filename_idx;


--
-- Name: focus_data_table_2030_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_03_tags_idx;


--
-- Name: focus_data_table_2030_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_04_source_filename_idx;


--
-- Name: focus_data_table_2030_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_04_tags_idx;


--
-- Name: focus_data_table_2030_05_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_05_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_05_source_filename_idx;


--
-- Name: focus_data_table_2030_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_05_tags_idx;


--
-- Name: focus_data_table_2030_06_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_06_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_06_source_filename_idx;


--
-- Name: focus_data_table_2030_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_06_tags_idx;


--
-- Name: focus_data_table_2030_07_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_07_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_07_source_filename_idx;


--
-- Name: focus_data_table_2030_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_07_tags_idx;


--
-- Name: focus_data_table_2030_08_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_08_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_08_source_filename_idx;


--
-- Name: focus_data_table_2030_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_08_tags_idx;


--
-- Name: focus_data_table_2030_09_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_09_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_09_source_filename_idx;


--
-- Name: focus_data_table_2030_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_09_tags_idx;


--
-- Name: focus_data_table_2030_10_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_10_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_10_source_filename_idx;


--
-- Name: focus_data_table_2030_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_10_tags_idx;


--
-- Name: focus_data_table_2030_11_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_11_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_11_source_filename_idx;


--
-- Name: focus_data_table_2030_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_11_tags_idx;


--
-- Name: focus_data_table_2030_12_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2030_12_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2030_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2030_12_source_filename_idx;


--
-- Name: focus_data_table_2030_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2030_12_tags_idx;


--
-- Name: focus_data_table_2031_01_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2031_01_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2031_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2031_01_source_filename_idx;


--
-- Name: focus_data_table_2031_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2031_01_tags_idx;


--
-- Name: focus_data_table_2031_02_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2031_02_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2031_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2031_02_source_filename_idx;


--
-- Name: focus_data_table_2031_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2031_02_tags_idx;


--
-- Name: focus_data_table_2031_03_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2031_03_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2031_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2031_03_source_filename_idx;


--
-- Name: focus_data_table_2031_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2031_03_tags_idx;


--
-- Name: focus_data_table_2031_04_oci_compartmentname_servicecategor_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_compartment ATTACH PARTITION public.focus_data_table_2031_04_oci_compartmentname_servicecategor_idx;


--
-- Name: focus_data_table_2031_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_source_file ATTACH PARTITION public.focus_data_table_2031_04_source_filename_idx;


--
-- Name: focus_data_table_2031_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_fcr_tags ATTACH PARTITION public.focus_data_table_2031_04_tags_idx;


--
-- Name: oci_cost_report_2025_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2025_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2025_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2025_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2025_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2025_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2025_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2025_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2025_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2025_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2025_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2025_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2025_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2025_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2025_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2025_10_source_filename_idx;


--
-- Name: oci_cost_report_2025_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2025_10_tags_idx;


--
-- Name: oci_cost_report_2025_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2025_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2025_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2025_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2025_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2025_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2025_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2025_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2025_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2025_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2025_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2025_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2025_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2025_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2025_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2025_11_source_filename_idx;


--
-- Name: oci_cost_report_2025_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2025_11_tags_idx;


--
-- Name: oci_cost_report_2025_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2025_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2025_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2025_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2025_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2025_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2025_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2025_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2025_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2025_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2025_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2025_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2025_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2025_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2025_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2025_12_source_filename_idx;


--
-- Name: oci_cost_report_2025_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2025_12_tags_idx;


--
-- Name: oci_cost_report_2026_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_01_source_filename_idx;


--
-- Name: oci_cost_report_2026_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_01_tags_idx;


--
-- Name: oci_cost_report_2026_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_02_source_filename_idx;


--
-- Name: oci_cost_report_2026_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_02_tags_idx;


--
-- Name: oci_cost_report_2026_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_03_source_filename_idx;


--
-- Name: oci_cost_report_2026_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_03_tags_idx;


--
-- Name: oci_cost_report_2026_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_04_source_filename_idx;


--
-- Name: oci_cost_report_2026_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_04_tags_idx;


--
-- Name: oci_cost_report_2026_05_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_05_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_05_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_05_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_05_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_05_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_05_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_05_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_05_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_05_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_05_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_05_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_05_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_05_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_05_source_filename_idx;


--
-- Name: oci_cost_report_2026_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_05_tags_idx;


--
-- Name: oci_cost_report_2026_06_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_06_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_06_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_06_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_06_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_06_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_06_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_06_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_06_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_06_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_06_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_06_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_06_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_06_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_06_source_filename_idx;


--
-- Name: oci_cost_report_2026_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_06_tags_idx;


--
-- Name: oci_cost_report_2026_07_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_07_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_07_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_07_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_07_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_07_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_07_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_07_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_07_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_07_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_07_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_07_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_07_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_07_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_07_source_filename_idx;


--
-- Name: oci_cost_report_2026_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_07_tags_idx;


--
-- Name: oci_cost_report_2026_08_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_08_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_08_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_08_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_08_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_08_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_08_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_08_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_08_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_08_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_08_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_08_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_08_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_08_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_08_source_filename_idx;


--
-- Name: oci_cost_report_2026_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_08_tags_idx;


--
-- Name: oci_cost_report_2026_09_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_09_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_09_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_09_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_09_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_09_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_09_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_09_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_09_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_09_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_09_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_09_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_09_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_09_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_09_source_filename_idx;


--
-- Name: oci_cost_report_2026_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_09_tags_idx;


--
-- Name: oci_cost_report_2026_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_10_source_filename_idx;


--
-- Name: oci_cost_report_2026_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_10_tags_idx;


--
-- Name: oci_cost_report_2026_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_11_source_filename_idx;


--
-- Name: oci_cost_report_2026_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_11_tags_idx;


--
-- Name: oci_cost_report_2026_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2026_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2026_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2026_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2026_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2026_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2026_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2026_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2026_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2026_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2026_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2026_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2026_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2026_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2026_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2026_12_source_filename_idx;


--
-- Name: oci_cost_report_2026_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2026_12_tags_idx;


--
-- Name: oci_cost_report_2027_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_01_source_filename_idx;


--
-- Name: oci_cost_report_2027_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_01_tags_idx;


--
-- Name: oci_cost_report_2027_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_02_source_filename_idx;


--
-- Name: oci_cost_report_2027_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_02_tags_idx;


--
-- Name: oci_cost_report_2027_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_03_source_filename_idx;


--
-- Name: oci_cost_report_2027_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_03_tags_idx;


--
-- Name: oci_cost_report_2027_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_04_source_filename_idx;


--
-- Name: oci_cost_report_2027_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_04_tags_idx;


--
-- Name: oci_cost_report_2027_05_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_05_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_05_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_05_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_05_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_05_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_05_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_05_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_05_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_05_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_05_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_05_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_05_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_05_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_05_source_filename_idx;


--
-- Name: oci_cost_report_2027_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_05_tags_idx;


--
-- Name: oci_cost_report_2027_06_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_06_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_06_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_06_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_06_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_06_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_06_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_06_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_06_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_06_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_06_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_06_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_06_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_06_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_06_source_filename_idx;


--
-- Name: oci_cost_report_2027_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_06_tags_idx;


--
-- Name: oci_cost_report_2027_07_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_07_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_07_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_07_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_07_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_07_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_07_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_07_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_07_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_07_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_07_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_07_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_07_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_07_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_07_source_filename_idx;


--
-- Name: oci_cost_report_2027_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_07_tags_idx;


--
-- Name: oci_cost_report_2027_08_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_08_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_08_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_08_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_08_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_08_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_08_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_08_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_08_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_08_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_08_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_08_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_08_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_08_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_08_source_filename_idx;


--
-- Name: oci_cost_report_2027_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_08_tags_idx;


--
-- Name: oci_cost_report_2027_09_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_09_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_09_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_09_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_09_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_09_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_09_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_09_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_09_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_09_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_09_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_09_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_09_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_09_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_09_source_filename_idx;


--
-- Name: oci_cost_report_2027_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_09_tags_idx;


--
-- Name: oci_cost_report_2027_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_10_source_filename_idx;


--
-- Name: oci_cost_report_2027_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_10_tags_idx;


--
-- Name: oci_cost_report_2027_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_11_source_filename_idx;


--
-- Name: oci_cost_report_2027_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_11_tags_idx;


--
-- Name: oci_cost_report_2027_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2027_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2027_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2027_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2027_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2027_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2027_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2027_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2027_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2027_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2027_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2027_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2027_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2027_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2027_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2027_12_source_filename_idx;


--
-- Name: oci_cost_report_2027_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2027_12_tags_idx;


--
-- Name: oci_cost_report_2028_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_01_source_filename_idx;


--
-- Name: oci_cost_report_2028_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_01_tags_idx;


--
-- Name: oci_cost_report_2028_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_02_source_filename_idx;


--
-- Name: oci_cost_report_2028_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_02_tags_idx;


--
-- Name: oci_cost_report_2028_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_03_source_filename_idx;


--
-- Name: oci_cost_report_2028_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_03_tags_idx;


--
-- Name: oci_cost_report_2028_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_04_source_filename_idx;


--
-- Name: oci_cost_report_2028_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_04_tags_idx;


--
-- Name: oci_cost_report_2028_05_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_05_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_05_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_05_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_05_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_05_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_05_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_05_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_05_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_05_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_05_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_05_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_05_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_05_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_05_source_filename_idx;


--
-- Name: oci_cost_report_2028_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_05_tags_idx;


--
-- Name: oci_cost_report_2028_06_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_06_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_06_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_06_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_06_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_06_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_06_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_06_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_06_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_06_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_06_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_06_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_06_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_06_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_06_source_filename_idx;


--
-- Name: oci_cost_report_2028_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_06_tags_idx;


--
-- Name: oci_cost_report_2028_07_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_07_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_07_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_07_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_07_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_07_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_07_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_07_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_07_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_07_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_07_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_07_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_07_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_07_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_07_source_filename_idx;


--
-- Name: oci_cost_report_2028_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_07_tags_idx;


--
-- Name: oci_cost_report_2028_08_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_08_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_08_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_08_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_08_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_08_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_08_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_08_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_08_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_08_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_08_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_08_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_08_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_08_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_08_source_filename_idx;


--
-- Name: oci_cost_report_2028_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_08_tags_idx;


--
-- Name: oci_cost_report_2028_09_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_09_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_09_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_09_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_09_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_09_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_09_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_09_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_09_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_09_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_09_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_09_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_09_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_09_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_09_source_filename_idx;


--
-- Name: oci_cost_report_2028_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_09_tags_idx;


--
-- Name: oci_cost_report_2028_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_10_source_filename_idx;


--
-- Name: oci_cost_report_2028_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_10_tags_idx;


--
-- Name: oci_cost_report_2028_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_11_source_filename_idx;


--
-- Name: oci_cost_report_2028_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_11_tags_idx;


--
-- Name: oci_cost_report_2028_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2028_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2028_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2028_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2028_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2028_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2028_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2028_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2028_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2028_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2028_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2028_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2028_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2028_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2028_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2028_12_source_filename_idx;


--
-- Name: oci_cost_report_2028_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2028_12_tags_idx;


--
-- Name: oci_cost_report_2029_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_01_source_filename_idx;


--
-- Name: oci_cost_report_2029_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_01_tags_idx;


--
-- Name: oci_cost_report_2029_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_02_source_filename_idx;


--
-- Name: oci_cost_report_2029_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_02_tags_idx;


--
-- Name: oci_cost_report_2029_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_03_source_filename_idx;


--
-- Name: oci_cost_report_2029_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_03_tags_idx;


--
-- Name: oci_cost_report_2029_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_04_source_filename_idx;


--
-- Name: oci_cost_report_2029_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_04_tags_idx;


--
-- Name: oci_cost_report_2029_05_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_05_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_05_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_05_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_05_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_05_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_05_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_05_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_05_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_05_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_05_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_05_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_05_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_05_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_05_source_filename_idx;


--
-- Name: oci_cost_report_2029_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_05_tags_idx;


--
-- Name: oci_cost_report_2029_06_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_06_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_06_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_06_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_06_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_06_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_06_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_06_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_06_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_06_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_06_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_06_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_06_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_06_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_06_source_filename_idx;


--
-- Name: oci_cost_report_2029_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_06_tags_idx;


--
-- Name: oci_cost_report_2029_07_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_07_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_07_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_07_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_07_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_07_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_07_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_07_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_07_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_07_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_07_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_07_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_07_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_07_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_07_source_filename_idx;


--
-- Name: oci_cost_report_2029_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_07_tags_idx;


--
-- Name: oci_cost_report_2029_08_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_08_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_08_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_08_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_08_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_08_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_08_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_08_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_08_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_08_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_08_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_08_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_08_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_08_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_08_source_filename_idx;


--
-- Name: oci_cost_report_2029_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_08_tags_idx;


--
-- Name: oci_cost_report_2029_09_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_09_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_09_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_09_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_09_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_09_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_09_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_09_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_09_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_09_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_09_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_09_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_09_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_09_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_09_source_filename_idx;


--
-- Name: oci_cost_report_2029_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_09_tags_idx;


--
-- Name: oci_cost_report_2029_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_10_source_filename_idx;


--
-- Name: oci_cost_report_2029_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_10_tags_idx;


--
-- Name: oci_cost_report_2029_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_11_source_filename_idx;


--
-- Name: oci_cost_report_2029_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_11_tags_idx;


--
-- Name: oci_cost_report_2029_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2029_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2029_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2029_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2029_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2029_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2029_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2029_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2029_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2029_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2029_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2029_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2029_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2029_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2029_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2029_12_source_filename_idx;


--
-- Name: oci_cost_report_2029_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2029_12_tags_idx;


--
-- Name: oci_cost_report_2030_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_01_source_filename_idx;


--
-- Name: oci_cost_report_2030_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_01_tags_idx;


--
-- Name: oci_cost_report_2030_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_02_source_filename_idx;


--
-- Name: oci_cost_report_2030_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_02_tags_idx;


--
-- Name: oci_cost_report_2030_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_03_source_filename_idx;


--
-- Name: oci_cost_report_2030_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_03_tags_idx;


--
-- Name: oci_cost_report_2030_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_04_source_filename_idx;


--
-- Name: oci_cost_report_2030_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_04_tags_idx;


--
-- Name: oci_cost_report_2030_05_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_05_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_05_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_05_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_05_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_05_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_05_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_05_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_05_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_05_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_05_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_05_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_05_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_05_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_05_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_05_source_filename_idx;


--
-- Name: oci_cost_report_2030_05_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_05_tags_idx;


--
-- Name: oci_cost_report_2030_06_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_06_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_06_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_06_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_06_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_06_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_06_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_06_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_06_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_06_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_06_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_06_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_06_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_06_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_06_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_06_source_filename_idx;


--
-- Name: oci_cost_report_2030_06_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_06_tags_idx;


--
-- Name: oci_cost_report_2030_07_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_07_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_07_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_07_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_07_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_07_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_07_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_07_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_07_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_07_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_07_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_07_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_07_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_07_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_07_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_07_source_filename_idx;


--
-- Name: oci_cost_report_2030_07_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_07_tags_idx;


--
-- Name: oci_cost_report_2030_08_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_08_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_08_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_08_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_08_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_08_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_08_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_08_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_08_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_08_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_08_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_08_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_08_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_08_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_08_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_08_source_filename_idx;


--
-- Name: oci_cost_report_2030_08_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_08_tags_idx;


--
-- Name: oci_cost_report_2030_09_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_09_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_09_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_09_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_09_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_09_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_09_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_09_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_09_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_09_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_09_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_09_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_09_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_09_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_09_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_09_source_filename_idx;


--
-- Name: oci_cost_report_2030_09_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_09_tags_idx;


--
-- Name: oci_cost_report_2030_10_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_10_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_10_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_10_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_10_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_10_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_10_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_10_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_10_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_10_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_10_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_10_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_10_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_10_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_10_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_10_source_filename_idx;


--
-- Name: oci_cost_report_2030_10_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_10_tags_idx;


--
-- Name: oci_cost_report_2030_11_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_11_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_11_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_11_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_11_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_11_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_11_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_11_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_11_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_11_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_11_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_11_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_11_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_11_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_11_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_11_source_filename_idx;


--
-- Name: oci_cost_report_2030_11_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_11_tags_idx;


--
-- Name: oci_cost_report_2030_12_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2030_12_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2030_12_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2030_12_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2030_12_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2030_12_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2030_12_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2030_12_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2030_12_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2030_12_product_compartmentname_idx;


--
-- Name: oci_cost_report_2030_12_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2030_12_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2030_12_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2030_12_product_resourceid_idx;


--
-- Name: oci_cost_report_2030_12_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2030_12_source_filename_idx;


--
-- Name: oci_cost_report_2030_12_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2030_12_tags_idx;


--
-- Name: oci_cost_report_2031_01_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2031_01_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2031_01_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2031_01_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2031_01_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2031_01_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2031_01_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2031_01_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2031_01_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2031_01_product_compartmentname_idx;


--
-- Name: oci_cost_report_2031_01_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2031_01_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2031_01_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2031_01_product_resourceid_idx;


--
-- Name: oci_cost_report_2031_01_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2031_01_source_filename_idx;


--
-- Name: oci_cost_report_2031_01_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2031_01_tags_idx;


--
-- Name: oci_cost_report_2031_02_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2031_02_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2031_02_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2031_02_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2031_02_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2031_02_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2031_02_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2031_02_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2031_02_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2031_02_product_compartmentname_idx;


--
-- Name: oci_cost_report_2031_02_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2031_02_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2031_02_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2031_02_product_resourceid_idx;


--
-- Name: oci_cost_report_2031_02_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2031_02_source_filename_idx;


--
-- Name: oci_cost_report_2031_02_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2031_02_tags_idx;


--
-- Name: oci_cost_report_2031_03_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2031_03_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2031_03_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2031_03_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2031_03_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2031_03_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2031_03_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2031_03_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2031_03_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2031_03_product_compartmentname_idx;


--
-- Name: oci_cost_report_2031_03_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2031_03_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2031_03_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2031_03_product_resourceid_idx;


--
-- Name: oci_cost_report_2031_03_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2031_03_source_filename_idx;


--
-- Name: oci_cost_report_2031_03_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2031_03_tags_idx;


--
-- Name: oci_cost_report_2031_04_lineitem_backreferenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_backreference ATTACH PARTITION public.oci_cost_report_2031_04_lineitem_backreferenceno_idx;


--
-- Name: oci_cost_report_2031_04_lineitem_iscorrection_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_correction ATTACH PARTITION public.oci_cost_report_2031_04_lineitem_iscorrection_idx;


--
-- Name: oci_cost_report_2031_04_lineitem_referenceno_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_referenceno ATTACH PARTITION public.oci_cost_report_2031_04_lineitem_referenceno_idx;


--
-- Name: oci_cost_report_2031_04_lineitem_tenantid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tenant ATTACH PARTITION public.oci_cost_report_2031_04_lineitem_tenantid_idx;


--
-- Name: oci_cost_report_2031_04_product_compartmentname_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment ATTACH PARTITION public.oci_cost_report_2031_04_product_compartmentname_idx;


--
-- Name: oci_cost_report_2031_04_product_region_product_compartmentn_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_compartment1 ATTACH PARTITION public.oci_cost_report_2031_04_product_region_product_compartmentn_idx;


--
-- Name: oci_cost_report_2031_04_product_resourceid_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_resource ATTACH PARTITION public.oci_cost_report_2031_04_product_resourceid_idx;


--
-- Name: oci_cost_report_2031_04_source_filename_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_source_file ATTACH PARTITION public.oci_cost_report_2031_04_source_filename_idx;


--
-- Name: oci_cost_report_2031_04_tags_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_ocr_tags ATTACH PARTITION public.oci_cost_report_2031_04_tags_idx;


--
-- PostgreSQL database dump complete
--

\unrestrict OAbbt7eb9lALdhhh2yao9F6fprVTjf92GYbdXV27YNs44RpFzXXWgpsoa5HYU6M

