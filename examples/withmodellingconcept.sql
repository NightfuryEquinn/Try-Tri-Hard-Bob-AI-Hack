/*
================================================================================
 LEGACY SQL-ONLY DATABASE TO FEATURE ENGINEERING TO MODELLING SCRIPT
 Dialect: PostgreSQL / psql style

 Purpose:
   This file imitates a heavy internship-style SQL workflow.
   It directly connects to a database, retrieves data, preprocesses the data,
   creates feature engineering tables, performs one-hot encoding, prepares
   distribution tables for graph plotting, and builds a SQL-based scoring model.

 Important:
   Pure SQL usually cannot directly create matplotlib images or train sklearn
   models. In real company workflows, the SQL file often prepares the graph
   data and model input table, then BI tools, Python, R, SAS, or database ML
   extensions continue the plotting and modelling part.

   This script therefore includes:
     - Direct DB connection command
     - Raw extraction
     - Temporary preprocessing tables
     - Feature engineering
     - One-hot encoding
     - Indexing
     - Distribution / histogram tables
     - Model input table
     - SQL-based risk scoring
     - Optional MADlib-style modelling section

 Warning:
   This is original mock SQL for learning and demonstration.
   It is intentionally long and confusing like old legacy enterprise files.
================================================================================
*/

-- ============================================================================
-- 00. CONNECTION AND SESSION SETUP
-- ============================================================================

-- psql command. Some SQL clients may ignore this line.
\connect legacy_confusing_dw

SET client_min_messages = WARNING;
SET search_path = public, raw_layer, stage_layer, feature_layer, report_layer, audit_layer;
SET timezone = 'Asia/Kuala_Lumpur';
SET statement_timeout = '0';
SET lock_timeout = '0';
SET idle_in_transaction_session_timeout = '0';
SET work_mem = '256MB';
SET maintenance_work_mem = '512MB';

-- ============================================================================
-- 01. SCHEMA CREATION
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS raw_layer;
CREATE SCHEMA IF NOT EXISTS stage_layer;
CREATE SCHEMA IF NOT EXISTS feature_layer;
CREATE SCHEMA IF NOT EXISTS plot_layer;
CREATE SCHEMA IF NOT EXISTS model_layer;
CREATE SCHEMA IF NOT EXISTS audit_layer;

-- ============================================================================
-- 02. AUDIT TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_layer.legacy_sql_run_log (
    run_id BIGSERIAL PRIMARY KEY,
    script_name TEXT,
    step_name TEXT,
    status TEXT,
    row_count BIGINT,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO audit_layer.legacy_sql_run_log(script_name, step_name, status, message)
VALUES ('legacy_sql_db_to_model_pipeline.sql', 'START_SCRIPT', 'STARTED', 'SQL-only database to model pipeline started');

-- ============================================================================
-- 03. MOCK RAW TABLE DEFINITIONS
-- ============================================================================
-- These are included so SQL tools can detect table names.
-- In real work, these raw tables usually already exist in the company database.

CREATE TABLE IF NOT EXISTS raw_layer.z_customer_master_legacy (
    c_id BIGINT PRIMARY KEY,
    c_code VARCHAR(40),
    c_full_name VARCHAR(255),
    c_email VARCHAR(255),
    c_region VARCHAR(80),
    c_country VARCHAR(80),
    c_gender VARCHAR(40),
    c_age_band VARCHAR(40),
    c_created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    c_updated_on TIMESTAMP,
    c_deleted_flag CHAR(1) DEFAULT 'N',
    c_source_system VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_customer_class_history_legacy (
    h_id BIGINT PRIMARY KEY,
    h_customer_id BIGINT,
    h_class_code VARCHAR(50),
    h_class_label VARCHAR(100),
    h_valid_from DATE,
    h_valid_to DATE,
    h_is_manual_override CHAR(1),
    h_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw_layer.z_product_dictionary_legacy (
    p_id BIGINT PRIMARY KEY,
    p_sku VARCHAR(80),
    p_name VARCHAR(255),
    p_family VARCHAR(100),
    p_category VARCHAR(100),
    p_cost NUMERIC(14,4),
    p_list_price NUMERIC(14,4),
    p_enabled_flag CHAR(1),
    p_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw_layer.z_sales_order_header_legacy (
    oh_id BIGINT PRIMARY KEY,
    oh_customer_id BIGINT,
    oh_order_no VARCHAR(80),
    oh_order_ts TIMESTAMP,
    oh_status VARCHAR(40),
    oh_discount_total NUMERIC(14,4),
    oh_shipping_total NUMERIC(14,4),
    oh_tax_total NUMERIC(14,4),
    oh_source_channel VARCHAR(80),
    oh_currency VARCHAR(20),
    oh_created_by VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_sales_order_line_legacy (
    ol_id BIGINT PRIMARY KEY,
    ol_order_id BIGINT,
    ol_product_id BIGINT,
    ol_qty NUMERIC(14,4),
    ol_unit_price NUMERIC(14,4),
    ol_line_status VARCHAR(40),
    ol_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw_layer.z_payment_attempt_legacy (
    pay_id BIGINT PRIMARY KEY,
    pay_order_id BIGINT,
    pay_status VARCHAR(40),
    pay_method VARCHAR(80),
    pay_amount NUMERIC(14,4),
    pay_created_ts TIMESTAMP,
    pay_captured_ts TIMESTAMP,
    pay_gateway_ref VARCHAR(255),
    pay_failure_code VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_return_case_legacy (
    r_id BIGINT PRIMARY KEY,
    r_order_id BIGINT,
    r_status VARCHAR(40),
    r_reason_code VARCHAR(80),
    r_created_ts TIMESTAMP,
    r_closed_ts TIMESTAMP,
    r_refund_amount NUMERIC(14,4),
    r_handler VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_support_case_legacy (
    s_id BIGINT PRIMARY KEY,
    s_customer_id BIGINT,
    s_status VARCHAR(40),
    s_priority VARCHAR(40),
    s_topic VARCHAR(120),
    s_created_ts TIMESTAMP,
    s_closed_ts TIMESTAMP,
    s_agent_group VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_marketing_touch_legacy (
    m_id BIGINT PRIMARY KEY,
    m_customer_id BIGINT,
    m_touch_type VARCHAR(80),
    m_campaign_code VARCHAR(120),
    m_touch_ts TIMESTAMP,
    m_cost NUMERIC(14,4),
    m_channel VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_customer_note_legacy (
    n_id BIGINT PRIMARY KEY,
    n_customer_id BIGINT,
    n_note_type VARCHAR(80),
    n_note_text TEXT,
    n_created_ts TIMESTAMP,
    n_created_by VARCHAR(80)
);

INSERT INTO audit_layer.legacy_sql_run_log(script_name, step_name, status, message)
VALUES ('legacy_sql_db_to_model_pipeline.sql', 'CREATE_RAW_TABLES', 'FINISHED', 'Raw table definitions checked');

-- ============================================================================
-- 04. INDEXING
-- ============================================================================

CREATE INDEX IF NOT EXISTS ix_cust_region_deleted ON raw_layer.z_customer_master_legacy(c_region, c_deleted_flag);
CREATE INDEX IF NOT EXISTS ix_cust_country_region ON raw_layer.z_customer_master_legacy(c_country, c_region);
CREATE INDEX IF NOT EXISTS ix_cust_created ON raw_layer.z_customer_master_legacy(c_created_on);
CREATE INDEX IF NOT EXISTS ix_cust_lower_email ON raw_layer.z_customer_master_legacy(LOWER(c_email));
CREATE INDEX IF NOT EXISTS ix_class_customer_valid ON raw_layer.z_customer_class_history_legacy(h_customer_id, h_valid_from, h_valid_to);
CREATE INDEX IF NOT EXISTS ix_class_override ON raw_layer.z_customer_class_history_legacy(h_customer_id, h_is_manual_override);
CREATE INDEX IF NOT EXISTS ix_product_family_category ON raw_layer.z_product_dictionary_legacy(p_family, p_category);
CREATE INDEX IF NOT EXISTS ix_product_enabled ON raw_layer.z_product_dictionary_legacy(p_enabled_flag);
CREATE INDEX IF NOT EXISTS ix_order_customer_ts ON raw_layer.z_sales_order_header_legacy(oh_customer_id, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_order_status_ts ON raw_layer.z_sales_order_header_legacy(oh_status, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_order_channel_ts ON raw_layer.z_sales_order_header_legacy(oh_source_channel, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_line_order ON raw_layer.z_sales_order_line_legacy(ol_order_id);
CREATE INDEX IF NOT EXISTS ix_line_product ON raw_layer.z_sales_order_line_legacy(ol_product_id);
CREATE INDEX IF NOT EXISTS ix_payment_order_status ON raw_layer.z_payment_attempt_legacy(pay_order_id, pay_status);
CREATE INDEX IF NOT EXISTS ix_payment_created ON raw_layer.z_payment_attempt_legacy(pay_created_ts);
CREATE INDEX IF NOT EXISTS ix_payment_captured ON raw_layer.z_payment_attempt_legacy(pay_captured_ts);
CREATE INDEX IF NOT EXISTS ix_return_order_status ON raw_layer.z_return_case_legacy(r_order_id, r_status);
CREATE INDEX IF NOT EXISTS ix_return_created ON raw_layer.z_return_case_legacy(r_created_ts);
CREATE INDEX IF NOT EXISTS ix_support_customer_status ON raw_layer.z_support_case_legacy(s_customer_id, s_status);
CREATE INDEX IF NOT EXISTS ix_support_priority_created ON raw_layer.z_support_case_legacy(s_priority, s_created_ts);
CREATE INDEX IF NOT EXISTS ix_marketing_customer_ts ON raw_layer.z_marketing_touch_legacy(m_customer_id, m_touch_ts);
CREATE INDEX IF NOT EXISTS ix_marketing_type_ts ON raw_layer.z_marketing_touch_legacy(m_touch_type, m_touch_ts);
CREATE INDEX IF NOT EXISTS ix_note_customer_ts ON raw_layer.z_customer_note_legacy(n_customer_id, n_created_ts);
CREATE INDEX IF NOT EXISTS ix_order_not_draft_partial ON raw_layer.z_sales_order_header_legacy(oh_customer_id, oh_order_ts) WHERE oh_status NOT IN ('DRAFT', 'TEST', 'SANDBOX');
CREATE INDEX IF NOT EXISTS ix_payment_success_partial ON raw_layer.z_payment_attempt_legacy(pay_order_id, pay_captured_ts) WHERE pay_status IN ('SUCCESS', 'CAPTURED', 'SETTLED');
CREATE INDEX IF NOT EXISTS ix_support_open_partial ON raw_layer.z_support_case_legacy(s_customer_id, s_created_ts) WHERE s_status NOT IN ('CLOSED', 'RESOLVED');

INSERT INTO audit_layer.legacy_sql_run_log(script_name, step_name, status, row_count, message)
VALUES ('legacy_sql_db_to_model_pipeline.sql', 'CREATE_INDEXES', 'FINISHED', 26, 'Indexes created or checked');

-- ============================================================================
-- 05. PARAMETER TABLE
-- ============================================================================

DROP TABLE IF EXISTS stage_layer.tmp_legacy_runtime_parameter;

CREATE TABLE stage_layer.tmp_legacy_runtime_parameter AS
SELECT
    DATE '2025-01-01' AS p_from_date,
    DATE '2025-12-31' AS p_to_date,
    NULL::VARCHAR AS p_region_filter,
    CURRENT_TIMESTAMP AS p_run_ts;

CREATE INDEX IF NOT EXISTS ix_tmp_runtime_parameter ON stage_layer.tmp_legacy_runtime_parameter(p_from_date, p_to_date);

-- ============================================================================
-- 06. DIRECT EXTRACTION FROM DATABASE INTO STAGING TABLES
-- ============================================================================

DROP TABLE IF EXISTS stage_layer.tmp_customer_clean_extract;

CREATE TABLE stage_layer.tmp_customer_clean_extract AS
SELECT
    c.c_id AS customer_id,
    COALESCE(NULLIF(TRIM(c.c_code), ''), 'NO_CODE') AS customer_code,
    COALESCE(NULLIF(TRIM(c.c_full_name), ''), 'UNKNOWN CUSTOMER') AS customer_name,
    LOWER(COALESCE(NULLIF(TRIM(c.c_email), ''), 'missing-email')) AS email_clean,
    COALESCE(NULLIF(TRIM(c.c_region), ''), 'UNKNOWN_REGION') AS region_clean,
    COALESCE(NULLIF(TRIM(c.c_country), ''), 'UNKNOWN_COUNTRY') AS country_clean,
    COALESCE(NULLIF(TRIM(c.c_gender), ''), 'UNKNOWN_GENDER') AS gender_clean,
    COALESCE(NULLIF(TRIM(c.c_age_band), ''), 'UNKNOWN_AGE') AS age_band_clean,
    c.c_created_on,
    c.c_updated_on,
    COALESCE(c.c_source_system, 'UNKNOWN_SOURCE') AS source_system_clean,
    COALESCE(EXTRACT(DAY FROM CURRENT_TIMESTAMP - c.c_created_on), 999999) AS account_age_days
FROM raw_layer.z_customer_master_legacy c
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter p
WHERE COALESCE(c.c_deleted_flag, 'N') <> 'Y'
  AND (p.p_region_filter IS NULL OR UPPER(c.c_region) = UPPER(p.p_region_filter));

CREATE INDEX IF NOT EXISTS ix_tmp_customer_clean_extract_id ON stage_layer.tmp_customer_clean_extract(customer_id);
CREATE INDEX IF NOT EXISTS ix_tmp_customer_clean_extract_region ON stage_layer.tmp_customer_clean_extract(region_clean);

DROP TABLE IF EXISTS stage_layer.tmp_customer_class_extract;

CREATE TABLE stage_layer.tmp_customer_class_extract AS
SELECT
    q.h_customer_id AS customer_id,
    COALESCE(q.h_class_label, q.h_class_code, 'NO_CLASS') AS class_clean,
    CASE WHEN q.h_is_manual_override = 'Y' THEN 1 ELSE 0 END AS class_manual_override_flag
FROM (
    SELECT
        h.*,
        ROW_NUMBER() OVER (
            PARTITION BY h.h_customer_id
            ORDER BY
                CASE WHEN h.h_is_manual_override = 'Y' THEN 0 ELSE 1 END,
                h.h_valid_from DESC,
                h.h_id DESC
        ) AS rn
    FROM raw_layer.z_customer_class_history_legacy h
    WHERE h.h_valid_from <= CURRENT_DATE
      AND COALESCE(h.h_valid_to, DATE '2999-12-31') >= CURRENT_DATE
) q
WHERE q.rn = 1;

CREATE INDEX IF NOT EXISTS ix_tmp_customer_class_extract_id ON stage_layer.tmp_customer_class_extract(customer_id);

DROP TABLE IF EXISTS stage_layer.tmp_order_line_extract;

CREATE TABLE stage_layer.tmp_order_line_extract AS
SELECT
    h.oh_customer_id AS customer_id,
    h.oh_id AS order_id,
    h.oh_order_no AS order_no,
    h.oh_order_ts AS order_ts,
    COALESCE(h.oh_status, 'UNKNOWN_STATUS') AS order_status,
    COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') AS source_channel,
    COALESCE(h.oh_currency, 'UNKNOWN_CURRENCY') AS currency_clean,
    COALESCE(h.oh_discount_total, 0) AS discount_total,
    COALESCE(h.oh_shipping_total, 0) AS shipping_total,
    COALESCE(h.oh_tax_total, 0) AS tax_total,
    l.ol_id AS line_id,
    l.ol_product_id AS product_id,
    COALESCE(l.ol_qty, 0) AS qty,
    COALESCE(l.ol_unit_price, 0) AS unit_price,
    COALESCE(l.ol_line_status, 'UNKNOWN_LINE_STATUS') AS line_status,
    COALESCE(pd.p_family, 'UNKNOWN_FAMILY') AS product_family,
    COALESCE(pd.p_category, 'UNKNOWN_CATEGORY') AS product_category,
    COALESCE(pd.p_cost, 0) AS product_cost,
    CASE WHEN COALESCE(l.ol_line_status, 'OK') IN ('VOID', 'CANCELLED') THEN 0 ELSE 1 END AS active_line_flag,
    COALESCE(l.ol_qty, 0) * COALESCE(l.ol_unit_price, 0) AS line_gross_amount,
    COALESCE(l.ol_qty, 0) * COALESCE(pd.p_cost, 0) AS line_cost_amount
FROM raw_layer.z_sales_order_header_legacy h
LEFT JOIN raw_layer.z_sales_order_line_legacy l
    ON h.oh_id = l.ol_order_id
LEFT JOIN raw_layer.z_product_dictionary_legacy pd
    ON l.ol_product_id = pd.p_id
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter p
WHERE h.oh_order_ts >= p.p_from_date
  AND h.oh_order_ts < p.p_to_date + INTERVAL '1 day'
  AND COALESCE(h.oh_status, 'UNKNOWN') NOT IN ('DRAFT', 'TEST', 'SANDBOX');

CREATE INDEX IF NOT EXISTS ix_tmp_order_line_extract_customer ON stage_layer.tmp_order_line_extract(customer_id);
CREATE INDEX IF NOT EXISTS ix_tmp_order_line_extract_order ON stage_layer.tmp_order_line_extract(order_id);
CREATE INDEX IF NOT EXISTS ix_tmp_order_line_extract_status ON stage_layer.tmp_order_line_extract(order_status);

-- ============================================================================
-- 07. ORDER LEVEL PREPROCESSING
-- ============================================================================

DROP TABLE IF EXISTS stage_layer.tmp_order_level_preprocessed;

CREATE TABLE stage_layer.tmp_order_level_preprocessed AS
SELECT
    customer_id,
    order_id,
    MAX(order_no) AS order_no,
    MAX(order_ts) AS order_ts,
    MAX(order_status) AS order_status,
    MAX(source_channel) AS source_channel,
    MAX(currency_clean) AS currency_clean,
    SUM(CASE WHEN active_line_flag = 1 THEN qty ELSE 0 END) AS order_units,
    SUM(CASE WHEN active_line_flag = 1 THEN line_gross_amount ELSE 0 END) AS order_gross_amount,
    SUM(CASE WHEN active_line_flag = 1 THEN line_cost_amount ELSE 0 END) AS order_cost_amount,
    MAX(discount_total) AS order_discount_amount,
    MAX(shipping_total) AS order_shipping_amount,
    MAX(tax_total) AS order_tax_amount,
    SUM(CASE WHEN product_family = 'PREMIUM' THEN 1 ELSE 0 END) AS order_premium_line_count,
    SUM(CASE WHEN product_family = 'ENTERPRISE' THEN 1 ELSE 0 END) AS order_enterprise_line_count,
    SUM(CASE WHEN product_family = 'BASIC' THEN 1 ELSE 0 END) AS order_basic_line_count,
    SUM(CASE WHEN product_category = 'HARDWARE' THEN 1 ELSE 0 END) AS order_hardware_line_count,
    SUM(CASE WHEN product_category = 'SOFTWARE' THEN 1 ELSE 0 END) AS order_software_line_count,
    SUM(CASE WHEN product_category = 'SERVICE' THEN 1 ELSE 0 END) AS order_service_line_count
FROM stage_layer.tmp_order_line_extract
GROUP BY customer_id, order_id;

CREATE INDEX IF NOT EXISTS ix_tmp_order_level_customer ON stage_layer.tmp_order_level_preprocessed(customer_id);
CREATE INDEX IF NOT EXISTS ix_tmp_order_level_order ON stage_layer.tmp_order_level_preprocessed(order_id);

-- ============================================================================
-- 08. CUSTOMER LEVEL AGGREGATION FEATURES
-- ============================================================================

DROP TABLE IF EXISTS feature_layer.tmp_order_features;

CREATE TABLE feature_layer.tmp_order_features AS
SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS feat_total_orders,
    COUNT(DISTINCT CASE WHEN order_status IN ('COMPLETED', 'SHIPPED', 'DELIVERED') THEN order_id END) AS feat_good_orders,
    COUNT(DISTINCT CASE WHEN order_status IN ('CANCELLED', 'FAILED', 'VOID') THEN order_id END) AS feat_bad_orders,
    SUM(order_units) AS feat_total_units,
    SUM(order_gross_amount) AS feat_gross_sales,
    SUM(order_cost_amount) AS feat_cost_amount,
    SUM(order_gross_amount - order_discount_amount - order_cost_amount) AS feat_margin_amount,
    AVG(order_gross_amount) AS feat_avg_order_value_sql,
    MAX(order_ts) AS feat_last_order_ts,
    MIN(order_ts) AS feat_first_order_ts,
    SUM(order_premium_line_count) AS feat_premium_line_count,
    SUM(order_enterprise_line_count) AS feat_enterprise_line_count,
    SUM(order_basic_line_count) AS feat_basic_line_count,
    SUM(order_hardware_line_count) AS feat_hardware_line_count,
    SUM(order_software_line_count) AS feat_software_line_count,
    SUM(order_service_line_count) AS feat_service_line_count,
    SUM(CASE WHEN source_channel = 'DIRECT' THEN 1 ELSE 0 END) AS feat_channel_direct_count,
    SUM(CASE WHEN source_channel = 'STORE' THEN 1 ELSE 0 END) AS feat_channel_store_count,
    SUM(CASE WHEN source_channel = 'AFFILIATE' THEN 1 ELSE 0 END) AS feat_channel_affiliate_count,
    SUM(CASE WHEN source_channel = 'MARKETPLACE' THEN 1 ELSE 0 END) AS feat_channel_marketplace_count,
    SUM(CASE WHEN currency_clean = 'USD' THEN 1 ELSE 0 END) AS feat_currency_usd_count,
    SUM(CASE WHEN currency_clean = 'MYR' THEN 1 ELSE 0 END) AS feat_currency_myr_count
FROM stage_layer.tmp_order_level_preprocessed
GROUP BY customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_order_features_customer ON feature_layer.tmp_order_features(customer_id);

-- Payment features
DROP TABLE IF EXISTS feature_layer.tmp_payment_features;

CREATE TABLE feature_layer.tmp_payment_features AS
SELECT
    h.oh_customer_id AS customer_id,
    COUNT(*) AS feat_payment_attempt_count,
    SUM(CASE WHEN p.pay_status IN ('SUCCESS', 'CAPTURED', 'SETTLED') THEN 1 ELSE 0 END) AS feat_payment_success_count,
    SUM(CASE WHEN p.pay_status IN ('FAILED', 'DECLINED', 'REVERSED') THEN 1 ELSE 0 END) AS feat_payment_failed_count,
    SUM(CASE WHEN p.pay_method = 'CARD' THEN 1 ELSE 0 END) AS feat_pay_card_count,
    SUM(CASE WHEN p.pay_method = 'BANK_TRANSFER' THEN 1 ELSE 0 END) AS feat_pay_bank_count,
    SUM(CASE WHEN p.pay_method = 'WALLET' THEN 1 ELSE 0 END) AS feat_pay_wallet_count,
    MAX(COALESCE(p.pay_captured_ts, p.pay_created_ts)) AS feat_last_payment_ts
FROM raw_layer.z_payment_attempt_legacy p
INNER JOIN raw_layer.z_sales_order_header_legacy h
    ON p.pay_order_id = h.oh_id
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter rp
WHERE COALESCE(p.pay_captured_ts, p.pay_created_ts) >= rp.p_from_date
  AND COALESCE(p.pay_captured_ts, p.pay_created_ts) < rp.p_to_date + INTERVAL '1 day'
GROUP BY h.oh_customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_payment_features_customer ON feature_layer.tmp_payment_features(customer_id);

-- Return features
DROP TABLE IF EXISTS feature_layer.tmp_return_features;

CREATE TABLE feature_layer.tmp_return_features AS
SELECT
    h.oh_customer_id AS customer_id,
    COUNT(*) AS feat_return_count,
    SUM(CASE WHEN r.r_status IN ('APPROVED', 'REFUNDED', 'PARTIAL_REFUND') THEN 1 ELSE 0 END) AS feat_real_return_count,
    SUM(CASE WHEN r.r_reason_code = 'DAMAGED' THEN 1 ELSE 0 END) AS feat_return_damaged_count,
    SUM(CASE WHEN r.r_reason_code = 'WRONG_ITEM' THEN 1 ELSE 0 END) AS feat_return_wrong_item_count,
    SUM(CASE WHEN r.r_reason_code = 'CHANGE_MIND' THEN 1 ELSE 0 END) AS feat_return_change_mind_count,
    SUM(COALESCE(r.r_refund_amount, 0)) AS feat_refund_amount,
    MAX(COALESCE(r.r_closed_ts, r.r_created_ts)) AS feat_last_return_ts
FROM raw_layer.z_return_case_legacy r
INNER JOIN raw_layer.z_sales_order_header_legacy h
    ON r.r_order_id = h.oh_id
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter rp
WHERE r.r_created_ts >= rp.p_from_date
  AND r.r_created_ts < rp.p_to_date + INTERVAL '1 day'
GROUP BY h.oh_customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_return_features_customer ON feature_layer.tmp_return_features(customer_id);

-- Support features
DROP TABLE IF EXISTS feature_layer.tmp_support_features;

CREATE TABLE feature_layer.tmp_support_features AS
SELECT
    s.s_customer_id AS customer_id,
    COUNT(*) AS feat_support_count,
    SUM(CASE WHEN s.s_status NOT IN ('CLOSED', 'RESOLVED') THEN 1 ELSE 0 END) AS feat_support_open_count,
    SUM(CASE WHEN s.s_priority IN ('HIGH', 'URGENT', 'CRITICAL') THEN 1 ELSE 0 END) AS feat_support_high_count,
    SUM(CASE WHEN s.s_topic = 'PAYMENT' THEN 1 ELSE 0 END) AS feat_support_payment_count,
    SUM(CASE WHEN s.s_topic = 'DELIVERY' THEN 1 ELSE 0 END) AS feat_support_delivery_count,
    SUM(CASE WHEN s.s_topic = 'PRODUCT' THEN 1 ELSE 0 END) AS feat_support_product_count,
    SUM(CASE WHEN s.s_agent_group = 'L1' THEN 1 ELSE 0 END) AS feat_support_l1_count,
    SUM(CASE WHEN s.s_agent_group = 'L2' THEN 1 ELSE 0 END) AS feat_support_l2_count,
    SUM(CASE WHEN s.s_agent_group = 'ESCALATION' THEN 1 ELSE 0 END) AS feat_support_escalation_count,
    MAX(COALESCE(s.s_closed_ts, s.s_created_ts)) AS feat_last_support_ts
FROM raw_layer.z_support_case_legacy s
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter rp
WHERE s.s_created_ts >= rp.p_from_date
  AND s.s_created_ts < rp.p_to_date + INTERVAL '1 day'
GROUP BY s.s_customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_support_features_customer ON feature_layer.tmp_support_features(customer_id);

-- Marketing features
DROP TABLE IF EXISTS feature_layer.tmp_marketing_features;

CREATE TABLE feature_layer.tmp_marketing_features AS
SELECT
    m.m_customer_id AS customer_id,
    COUNT(*) AS feat_marketing_touch_count,
    SUM(CASE WHEN m.m_touch_type IN ('EMAIL_OPEN', 'EMAIL_CLICK', 'AD_CLICK', 'PUSH_CLICK') THEN 1 ELSE 0 END) AS feat_marketing_positive_count,
    SUM(CASE WHEN m.m_touch_type IN ('UNSUBSCRIBE', 'SPAM_REPORT') THEN 1 ELSE 0 END) AS feat_marketing_negative_count,
    SUM(CASE WHEN m.m_channel = 'EMAIL' THEN 1 ELSE 0 END) AS feat_marketing_email_count,
    SUM(CASE WHEN m.m_channel = 'PUSH' THEN 1 ELSE 0 END) AS feat_marketing_push_count,
    SUM(CASE WHEN m.m_channel = 'AD' THEN 1 ELSE 0 END) AS feat_marketing_ad_count,
    SUM(CASE WHEN m.m_channel = 'PARTNER' THEN 1 ELSE 0 END) AS feat_marketing_partner_count,
    SUM(COALESCE(m.m_cost, 0)) AS feat_marketing_cost,
    MAX(m.m_touch_ts) AS feat_last_marketing_ts
FROM raw_layer.z_marketing_touch_legacy m
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter rp
WHERE m.m_touch_ts >= rp.p_from_date
  AND m.m_touch_ts < rp.p_to_date + INTERVAL '1 day'
GROUP BY m.m_customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_marketing_features_customer ON feature_layer.tmp_marketing_features(customer_id);

-- Note text features
DROP TABLE IF EXISTS feature_layer.tmp_note_features;

CREATE TABLE feature_layer.tmp_note_features AS
SELECT
    n.n_customer_id AS customer_id,
    COUNT(*) AS feat_note_count,
    SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%fraud%' THEN 1 ELSE 0 END) AS feat_note_fraud_count,
    SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%angry%' THEN 1 ELSE 0 END) AS feat_note_angry_count,
    SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%vip%' THEN 1 ELSE 0 END) AS feat_note_vip_count,
    SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%refund%' THEN 1 ELSE 0 END) AS feat_note_refund_count,
    SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%complaint%' THEN 1 ELSE 0 END) AS feat_note_complaint_count,
    MAX(n.n_created_ts) AS feat_last_note_ts
FROM raw_layer.z_customer_note_legacy n
CROSS JOIN stage_layer.tmp_legacy_runtime_parameter rp
WHERE n.n_created_ts >= rp.p_from_date
  AND n.n_created_ts < rp.p_to_date + INTERVAL '1 day'
GROUP BY n.n_customer_id;

CREATE INDEX IF NOT EXISTS ix_tmp_note_features_customer ON feature_layer.tmp_note_features(customer_id);

INSERT INTO audit_layer.legacy_sql_run_log(script_name, step_name, status, message)
VALUES ('legacy_sql_db_to_model_pipeline.sql', 'FEATURE_AGGREGATION', 'FINISHED', 'Feature aggregation tables created');

-- ============================================================================
-- 09. FINAL FEATURE ENGINEERING TABLE WITH ONE-HOT ENCODING
-- ============================================================================

DROP TABLE IF EXISTS feature_layer.customer_model_feature_matrix_legacy;

CREATE TABLE feature_layer.customer_model_feature_matrix_legacy AS
SELECT
    c.customer_id,
    c.customer_code,
    c.customer_name,
    c.email_clean,
    c.region_clean,
    c.country_clean,
    c.gender_clean,
    c.age_band_clean,
    COALESCE(cls.class_clean, 'NO_CLASS') AS class_clean,
    COALESCE(cls.class_manual_override_flag, 0) AS feat_class_manual_override_flag,
    COALESCE(c.account_age_days, 999999) AS account_age_days,
    CASE WHEN COALESCE(c.account_age_days, 999999) <= 30 THEN 1 ELSE 0 END AS feat_account_new_30d,
    CASE WHEN COALESCE(c.account_age_days, 999999) BETWEEN 31 AND 180 THEN 1 ELSE 0 END AS feat_account_mid_31_180d,
    CASE WHEN COALESCE(c.account_age_days, 999999) > 180 THEN 1 ELSE 0 END AS feat_account_old_180d_plus,
    COALESCE(o.feat_total_orders, 0) AS feat_total_orders,
    COALESCE(o.feat_good_orders, 0) AS feat_good_orders,
    COALESCE(o.feat_bad_orders, 0) AS feat_bad_orders,
    COALESCE(o.feat_total_units, 0) AS feat_total_units,
    COALESCE(o.feat_gross_sales, 0) AS feat_gross_sales,
    COALESCE(o.feat_cost_amount, 0) AS feat_cost_amount,
    COALESCE(o.feat_margin_amount, 0) AS feat_margin_amount,
    COALESCE(o.feat_avg_order_value_sql, 0) AS feat_avg_order_value_sql,
    COALESCE(o.feat_premium_line_count, 0) AS feat_premium_line_count,
    COALESCE(o.feat_enterprise_line_count, 0) AS feat_enterprise_line_count,
    COALESCE(o.feat_basic_line_count, 0) AS feat_basic_line_count,
    COALESCE(o.feat_hardware_line_count, 0) AS feat_hardware_line_count,
    COALESCE(o.feat_software_line_count, 0) AS feat_software_line_count,
    COALESCE(o.feat_service_line_count, 0) AS feat_service_line_count,
    COALESCE(o.feat_channel_direct_count, 0) AS feat_channel_direct_count,
    COALESCE(o.feat_channel_store_count, 0) AS feat_channel_store_count,
    COALESCE(o.feat_channel_affiliate_count, 0) AS feat_channel_affiliate_count,
    COALESCE(o.feat_channel_marketplace_count, 0) AS feat_channel_marketplace_count,
    COALESCE(o.feat_currency_usd_count, 0) AS feat_currency_usd_count,
    COALESCE(o.feat_currency_myr_count, 0) AS feat_currency_myr_count,
    COALESCE(p.feat_payment_attempt_count, 0) AS feat_payment_attempt_count,
    COALESCE(p.feat_payment_success_count, 0) AS feat_payment_success_count,
    COALESCE(p.feat_payment_failed_count, 0) AS feat_payment_failed_count,
    COALESCE(p.feat_pay_card_count, 0) AS feat_pay_card_count,
    COALESCE(p.feat_pay_bank_count, 0) AS feat_pay_bank_count,
    COALESCE(p.feat_pay_wallet_count, 0) AS feat_pay_wallet_count,
    ROUND(CASE WHEN COALESCE(p.feat_payment_attempt_count, 0) = 0 THEN 0 ELSE p.feat_payment_success_count * 100.0 / NULLIF(p.feat_payment_attempt_count, 0) END, 4) AS feat_payment_success_pct,
    COALESCE(r.feat_return_count, 0) AS feat_return_count,
    COALESCE(r.feat_real_return_count, 0) AS feat_real_return_count,
    COALESCE(r.feat_return_damaged_count, 0) AS feat_return_damaged_count,
    COALESCE(r.feat_return_wrong_item_count, 0) AS feat_return_wrong_item_count,
    COALESCE(r.feat_return_change_mind_count, 0) AS feat_return_change_mind_count,
    COALESCE(r.feat_refund_amount, 0) AS feat_refund_amount,
    COALESCE(s.feat_support_count, 0) AS feat_support_count,
    COALESCE(s.feat_support_open_count, 0) AS feat_support_open_count,
    COALESCE(s.feat_support_high_count, 0) AS feat_support_high_count,
    COALESCE(s.feat_support_payment_count, 0) AS feat_support_payment_count,
    COALESCE(s.feat_support_delivery_count, 0) AS feat_support_delivery_count,
    COALESCE(s.feat_support_product_count, 0) AS feat_support_product_count,
    COALESCE(s.feat_support_l1_count, 0) AS feat_support_l1_count,
    COALESCE(s.feat_support_l2_count, 0) AS feat_support_l2_count,
    COALESCE(s.feat_support_escalation_count, 0) AS feat_support_escalation_count,
    COALESCE(m.feat_marketing_touch_count, 0) AS feat_marketing_touch_count,
    COALESCE(m.feat_marketing_positive_count, 0) AS feat_marketing_positive_count,
    COALESCE(m.feat_marketing_negative_count, 0) AS feat_marketing_negative_count,
    COALESCE(m.feat_marketing_email_count, 0) AS feat_marketing_email_count,
    COALESCE(m.feat_marketing_push_count, 0) AS feat_marketing_push_count,
    COALESCE(m.feat_marketing_ad_count, 0) AS feat_marketing_ad_count,
    COALESCE(m.feat_marketing_partner_count, 0) AS feat_marketing_partner_count,
    COALESCE(m.feat_marketing_cost, 0) AS feat_marketing_cost,
    COALESCE(n.feat_note_count, 0) AS feat_note_count,
    COALESCE(n.feat_note_fraud_count, 0) AS feat_note_fraud_count,
    COALESCE(n.feat_note_angry_count, 0) AS feat_note_angry_count,
    COALESCE(n.feat_note_vip_count, 0) AS feat_note_vip_count,
    COALESCE(n.feat_note_refund_count, 0) AS feat_note_refund_count,
    COALESCE(n.feat_note_complaint_count, 0) AS feat_note_complaint_count,
    GREATEST(
        COALESCE(o.feat_last_order_ts, TIMESTAMP '1900-01-01'),
        COALESCE(p.feat_last_payment_ts, TIMESTAMP '1900-01-01'),
        COALESCE(r.feat_last_return_ts, TIMESTAMP '1900-01-01'),
        COALESCE(s.feat_last_support_ts, TIMESTAMP '1900-01-01'),
        COALESCE(m.feat_last_marketing_ts, TIMESTAMP '1900-01-01'),
        COALESCE(n.feat_last_note_ts, TIMESTAMP '1900-01-01')
    ) AS feat_last_any_activity_ts,
    CASE WHEN COALESCE(o.feat_total_orders, 0) = 0 THEN 1 ELSE 0 END AS feat_no_order_flag,
    CASE WHEN ROUND(CASE WHEN COALESCE(p.feat_payment_attempt_count, 0) = 0 THEN 0 ELSE p.feat_payment_success_count * 100.0 / NULLIF(p.feat_payment_attempt_count, 0) END, 4) < 70 AND COALESCE(p.feat_payment_attempt_count, 0) > 0 THEN 1 ELSE 0 END AS feat_bad_payment_flag,
    CASE WHEN COALESCE(r.feat_real_return_count, 0) >= 3 THEN 1 ELSE 0 END AS feat_high_return_flag,
    CASE WHEN COALESCE(s.feat_support_open_count, 0) >= 5 THEN 1 ELSE 0 END AS feat_support_pressure_flag,
    CASE WHEN COALESCE(m.feat_marketing_negative_count, 0) >= 2 THEN 1 ELSE 0 END AS feat_marketing_negative_flag,
    CASE WHEN COALESCE(n.feat_note_fraud_count, 0) > 0 THEN 1 ELSE 0 END AS feat_note_fraud_flag,
    ROUND(CASE WHEN COALESCE(o.feat_total_orders, 0) = 0 THEN 0 ELSE COALESCE(o.feat_gross_sales, 0) / NULLIF(o.feat_total_orders, 0) END, 4) AS feat_avg_order_value,
    ROUND(CASE WHEN COALESCE(o.feat_gross_sales, 0) = 0 THEN 0 ELSE COALESCE(o.feat_margin_amount, 0) / NULLIF(o.feat_gross_sales, 0) END, 4) AS feat_margin_ratio,
    ROUND(CASE WHEN COALESCE(o.feat_total_orders, 0) = 0 THEN 0 ELSE COALESCE(r.feat_real_return_count, 0) * 1.0 / NULLIF(o.feat_total_orders, 0) END, 4) AS feat_return_rate,
    ROUND(CASE WHEN COALESCE(o.feat_total_orders, 0) = 0 THEN 0 ELSE COALESCE(s.feat_support_count, 0) * 1.0 / NULLIF(o.feat_total_orders, 0) END, 4) AS feat_support_per_order,
    ROUND(CASE WHEN COALESCE(m.feat_marketing_touch_count, 0) = 0 THEN 0 ELSE COALESCE(m.feat_marketing_positive_count, 0) * 1.0 / NULLIF(m.feat_marketing_touch_count, 0) END, 4) AS feat_marketing_positive_ratio,
    CASE WHEN UPPER(c.region_clean) = 'APAC' THEN 1 ELSE 0 END AS ohe_region_apac,
    CASE WHEN UPPER(c.region_clean) = 'EMEA' THEN 1 ELSE 0 END AS ohe_region_emea,
    CASE WHEN UPPER(c.region_clean) = 'AMER' THEN 1 ELSE 0 END AS ohe_region_amer,
    CASE WHEN UPPER(c.region_clean) = 'ASEAN' THEN 1 ELSE 0 END AS ohe_region_asean,
    CASE WHEN UPPER(c.region_clean) = 'MALAYSIA' THEN 1 ELSE 0 END AS ohe_region_malaysia,
    CASE WHEN UPPER(c.region_clean) = 'SINGAPORE' THEN 1 ELSE 0 END AS ohe_region_singapore,
    CASE WHEN UPPER(c.region_clean) = 'THAILAND' THEN 1 ELSE 0 END AS ohe_region_thailand,
    CASE WHEN UPPER(c.region_clean) = 'CHINA' THEN 1 ELSE 0 END AS ohe_region_china,
    CASE WHEN UPPER(c.region_clean) = 'INDIA' THEN 1 ELSE 0 END AS ohe_region_india,
    CASE WHEN UPPER(c.region_clean) = 'JAPAN' THEN 1 ELSE 0 END AS ohe_region_japan,
    CASE WHEN UPPER(c.region_clean) = 'KOREA' THEN 1 ELSE 0 END AS ohe_region_korea,
    CASE WHEN UPPER(c.region_clean) = 'EUROPE' THEN 1 ELSE 0 END AS ohe_region_europe,
    CASE WHEN UPPER(c.region_clean) = 'UNKNOWN_REGION' THEN 1 ELSE 0 END AS ohe_region_unknown_region,
    CASE WHEN UPPER(c.country_clean) = 'MALAYSIA' THEN 1 ELSE 0 END AS ohe_country_malaysia,
    CASE WHEN UPPER(c.country_clean) = 'SINGAPORE' THEN 1 ELSE 0 END AS ohe_country_singapore,
    CASE WHEN UPPER(c.country_clean) = 'THAILAND' THEN 1 ELSE 0 END AS ohe_country_thailand,
    CASE WHEN UPPER(c.country_clean) = 'CHINA' THEN 1 ELSE 0 END AS ohe_country_china,
    CASE WHEN UPPER(c.country_clean) = 'INDIA' THEN 1 ELSE 0 END AS ohe_country_india,
    CASE WHEN UPPER(c.country_clean) = 'JAPAN' THEN 1 ELSE 0 END AS ohe_country_japan,
    CASE WHEN UPPER(c.country_clean) = 'KOREA' THEN 1 ELSE 0 END AS ohe_country_korea,
    CASE WHEN UPPER(c.country_clean) = 'USA' THEN 1 ELSE 0 END AS ohe_country_usa,
    CASE WHEN UPPER(c.country_clean) = 'GERMANY' THEN 1 ELSE 0 END AS ohe_country_germany,
    CASE WHEN UPPER(c.country_clean) = 'UNKNOWN_COUNTRY' THEN 1 ELSE 0 END AS ohe_country_unknown_country,
    CASE WHEN UPPER(c.gender_clean) = 'MALE' THEN 1 ELSE 0 END AS ohe_gender_male,
    CASE WHEN UPPER(c.gender_clean) = 'FEMALE' THEN 1 ELSE 0 END AS ohe_gender_female,
    CASE WHEN UPPER(c.gender_clean) = 'UNKNOWN_GENDER' THEN 1 ELSE 0 END AS ohe_gender_unknown_gender,
    CASE WHEN UPPER(c.age_band_clean) = '18_25' THEN 1 ELSE 0 END AS ohe_age_18_25,
    CASE WHEN UPPER(c.age_band_clean) = '26_35' THEN 1 ELSE 0 END AS ohe_age_26_35,
    CASE WHEN UPPER(c.age_band_clean) = '36_45' THEN 1 ELSE 0 END AS ohe_age_36_45,
    CASE WHEN UPPER(c.age_band_clean) = '46_55' THEN 1 ELSE 0 END AS ohe_age_46_55,
    CASE WHEN UPPER(c.age_band_clean) = '56_PLUS' THEN 1 ELSE 0 END AS ohe_age_56_plus,
    CASE WHEN UPPER(c.age_band_clean) = 'UNKNOWN_AGE' THEN 1 ELSE 0 END AS ohe_age_unknown_age,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'VIP' THEN 1 ELSE 0 END AS ohe_class_vip,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'GOLD' THEN 1 ELSE 0 END AS ohe_class_gold,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'SILVER' THEN 1 ELSE 0 END AS ohe_class_silver,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'BRONZE' THEN 1 ELSE 0 END AS ohe_class_bronze,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'RISK' THEN 1 ELSE 0 END AS ohe_class_risk,
    CASE WHEN UPPER(COALESCE(cls.class_clean, 'NO_CLASS')) = 'NO_CLASS' THEN 1 ELSE 0 END AS ohe_class_no_class
FROM stage_layer.tmp_customer_clean_extract c
LEFT JOIN stage_layer.tmp_customer_class_extract cls
    ON cls.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_order_features o
    ON o.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_payment_features p
    ON p.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_return_features r
    ON r.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_support_features s
    ON s.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_marketing_features m
    ON m.customer_id = c.customer_id
LEFT JOIN feature_layer.tmp_note_features n
    ON n.customer_id = c.customer_id;

CREATE UNIQUE INDEX IF NOT EXISTS ux_customer_model_feature_matrix_customer ON feature_layer.customer_model_feature_matrix_legacy(customer_id);
CREATE INDEX IF NOT EXISTS ix_customer_model_feature_matrix_region ON feature_layer.customer_model_feature_matrix_legacy(region_clean);
CREATE INDEX IF NOT EXISTS ix_customer_model_feature_matrix_class ON feature_layer.customer_model_feature_matrix_legacy(class_clean);
CREATE INDEX IF NOT EXISTS ix_customer_model_feature_matrix_sales ON feature_layer.customer_model_feature_matrix_legacy(feat_gross_sales, feat_margin_amount);
CREATE INDEX IF NOT EXISTS ix_customer_model_feature_matrix_activity ON feature_layer.customer_model_feature_matrix_legacy(feat_last_any_activity_ts);

-- ============================================================================
-- 10. CREATE LABEL / TARGET COLUMN
-- ============================================================================

ALTER TABLE feature_layer.customer_model_feature_matrix_legacy
DROP COLUMN IF EXISTS label_customer_risk;

ALTER TABLE feature_layer.customer_model_feature_matrix_legacy
ADD COLUMN label_customer_risk INTEGER;

UPDATE feature_layer.customer_model_feature_matrix_legacy
SET label_customer_risk =
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 1
        WHEN feat_high_return_flag = 1 THEN 1
        WHEN feat_support_pressure_flag = 1 THEN 1
        WHEN feat_note_fraud_flag = 1 THEN 1
        WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 1
        ELSE 0
    END;

CREATE INDEX IF NOT EXISTS ix_customer_model_feature_matrix_label ON feature_layer.customer_model_feature_matrix_legacy(label_customer_risk);

-- ============================================================================
-- 11. DISTRIBUTION TABLES FOR PLOTTING GRAPHS
-- ============================================================================
-- SQL does not usually render charts directly.
-- These tables are graph-ready. BI tools, Python, R, or dashboard tools can plot them.

DROP TABLE IF EXISTS plot_layer.customer_numeric_distribution_long;

CREATE TABLE plot_layer.customer_numeric_distribution_long (
    feature_name TEXT,
    bucket_no INTEGER,
    bucket_min NUMERIC,
    bucket_max NUMERIC,
    row_count BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'account_age_days' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(account_age_days, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE account_age_days IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(account_age_days, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE account_age_days IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_total_orders' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_total_orders, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_total_orders IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_total_orders, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_total_orders IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_good_orders' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_good_orders, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_good_orders IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_good_orders, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_good_orders IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_bad_orders' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_bad_orders, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_bad_orders IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_bad_orders, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_bad_orders IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_total_units' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_total_units, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_total_units IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_total_units, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_total_units IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_gross_sales' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_gross_sales, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_gross_sales IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_gross_sales, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_gross_sales IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_cost_amount' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_cost_amount, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_cost_amount IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_cost_amount, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_cost_amount IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_margin_amount' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_margin_amount, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_margin_amount IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_margin_amount, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_margin_amount IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_avg_order_value_sql' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_avg_order_value_sql, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_avg_order_value_sql IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_avg_order_value_sql, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_avg_order_value_sql IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_payment_attempt_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_payment_attempt_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_payment_attempt_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_payment_attempt_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_payment_attempt_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_payment_success_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_payment_success_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_payment_success_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_payment_success_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_payment_success_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_payment_failed_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_payment_failed_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_payment_failed_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_payment_failed_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_payment_failed_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_payment_success_pct' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_payment_success_pct, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_payment_success_pct IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_payment_success_pct, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_payment_success_pct IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_return_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_return_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_return_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_return_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_return_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_real_return_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_real_return_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_real_return_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_real_return_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_real_return_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_refund_amount' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_refund_amount, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_refund_amount IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_refund_amount, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_refund_amount IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_support_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_support_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_support_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_support_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_support_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_support_open_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_support_open_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_support_open_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_support_open_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_support_open_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_support_high_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_support_high_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_support_high_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_support_high_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_support_high_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_marketing_touch_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_marketing_touch_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_marketing_touch_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_marketing_touch_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_marketing_touch_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_marketing_positive_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_marketing_positive_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_marketing_positive_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_marketing_positive_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_marketing_positive_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_marketing_negative_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_marketing_negative_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_marketing_negative_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_marketing_negative_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_marketing_negative_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_marketing_cost' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_marketing_cost, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_marketing_cost IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_marketing_cost, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_marketing_cost IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_fraud_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_fraud_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_fraud_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_fraud_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_fraud_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_angry_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_angry_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_angry_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_angry_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_angry_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_vip_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_vip_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_vip_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_vip_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_vip_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_refund_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_refund_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_refund_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_refund_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_refund_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_note_complaint_count' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_note_complaint_count, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_note_complaint_count IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_note_complaint_count, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_note_complaint_count IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_avg_order_value' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_avg_order_value, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_avg_order_value IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_avg_order_value, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_avg_order_value IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_margin_ratio' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_margin_ratio, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_margin_ratio IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_margin_ratio, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_margin_ratio IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_return_rate' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_return_rate, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_return_rate IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_return_rate, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_return_rate IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_support_per_order' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_support_per_order, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_support_per_order IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_support_per_order, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_support_per_order IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

INSERT INTO plot_layer.customer_numeric_distribution_long(feature_name, bucket_no, bucket_min, bucket_max, row_count)
SELECT
    'feat_marketing_positive_ratio' AS feature_name,
    width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20) AS bucket_no,
    MIN(x.val) AS bucket_min,
    MAX(x.val) AS bucket_max,
    COUNT(*) AS row_count
FROM (
    SELECT COALESCE(feat_marketing_positive_ratio, 0)::NUMERIC AS val
    FROM feature_layer.customer_model_feature_matrix_legacy
    WHERE feat_marketing_positive_ratio IS NOT NULL
) x
CROSS JOIN (
    SELECT
        MIN(COALESCE(val, 0)) AS min_val,
        MAX(COALESCE(val, 0)) AS max_val
    FROM (
        SELECT COALESCE(feat_marketing_positive_ratio, 0)::NUMERIC AS val
        FROM feature_layer.customer_model_feature_matrix_legacy
        WHERE feat_marketing_positive_ratio IS NOT NULL
    ) t
) s
GROUP BY width_bucket(x.val, s.min_val, s.max_val + 0.000001, 20)
ORDER BY bucket_no;

DROP TABLE IF EXISTS plot_layer.customer_categorical_distribution_long;

CREATE TABLE plot_layer.customer_categorical_distribution_long AS

SELECT
    'region_clean' AS feature_name,
    COALESCE(region_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(region_clean::TEXT, 'UNKNOWN')
UNION ALL
SELECT
    'country_clean' AS feature_name,
    COALESCE(country_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(country_clean::TEXT, 'UNKNOWN')
UNION ALL
SELECT
    'gender_clean' AS feature_name,
    COALESCE(gender_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(gender_clean::TEXT, 'UNKNOWN')
UNION ALL
SELECT
    'age_band_clean' AS feature_name,
    COALESCE(age_band_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(age_band_clean::TEXT, 'UNKNOWN')
UNION ALL
SELECT
    'class_clean' AS feature_name,
    COALESCE(class_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(class_clean::TEXT, 'UNKNOWN')
UNION ALL
SELECT
    'source_system_clean' AS feature_name,
    COALESCE(source_system_clean::TEXT, 'UNKNOWN') AS category_value,
    COUNT(*) AS row_count,
    CURRENT_TIMESTAMP AS created_at
FROM feature_layer.customer_model_feature_matrix_legacy
GROUP BY COALESCE(source_system_clean::TEXT, 'UNKNOWN')
;

CREATE INDEX IF NOT EXISTS ix_numeric_distribution_feature ON plot_layer.customer_numeric_distribution_long(feature_name);
CREATE INDEX IF NOT EXISTS ix_categorical_distribution_feature ON plot_layer.customer_categorical_distribution_long(feature_name);

-- ============================================================================
-- 12. SQL-BASED MODELLING / SCORING
-- ============================================================================
-- This is not machine learning in the sklearn sense.
-- It is a rule-based SQL model that behaves like old production scoring logic.

DROP TABLE IF EXISTS model_layer.customer_sql_score_model_output;

CREATE TABLE model_layer.customer_sql_score_model_output AS
SELECT
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    label_customer_risk,
    (
        CASE WHEN feat_no_order_flag = 1 THEN 25 ELSE 0 END
        + CASE WHEN feat_bad_payment_flag = 1 THEN 30 ELSE 0 END
        + CASE WHEN feat_high_return_flag = 1 THEN 25 ELSE 0 END
        + CASE WHEN feat_support_pressure_flag = 1 THEN 20 ELSE 0 END
        + CASE WHEN feat_marketing_negative_flag = 1 THEN 10 ELSE 0 END
        + CASE WHEN feat_note_fraud_flag = 1 THEN 35 ELSE 0 END
        + CASE WHEN feat_payment_success_pct < 60 AND feat_payment_attempt_count > 0 THEN 15 ELSE 0 END
        + CASE WHEN feat_return_rate > 0.30 THEN 15 ELSE 0 END
        + CASE WHEN feat_support_per_order > 1 THEN 8 ELSE 0 END
        + CASE WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 12 ELSE 0 END
        + CASE WHEN feat_note_complaint_count >= 2 THEN 8 ELSE 0 END
        + CASE WHEN feat_gross_sales >= 20000 THEN -12 ELSE 0 END
        + CASE WHEN feat_margin_amount >= 5000 THEN -10 ELSE 0 END
        + CASE WHEN ohe_class_vip = 1 THEN -10 ELSE 0 END
        + CASE WHEN ohe_class_gold = 1 THEN -5 ELSE 0 END
        + CASE WHEN feat_marketing_positive_ratio >= 0.50 THEN -3 ELSE 0 END
    )::NUMERIC AS sql_model_risk_score,
    CASE
        WHEN (
            CASE WHEN feat_no_order_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_bad_payment_flag = 1 THEN 30 ELSE 0 END
            + CASE WHEN feat_high_return_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_support_pressure_flag = 1 THEN 20 ELSE 0 END
            + CASE WHEN feat_marketing_negative_flag = 1 THEN 10 ELSE 0 END
            + CASE WHEN feat_note_fraud_flag = 1 THEN 35 ELSE 0 END
            + CASE WHEN feat_payment_success_pct < 60 AND feat_payment_attempt_count > 0 THEN 15 ELSE 0 END
            + CASE WHEN feat_return_rate > 0.30 THEN 15 ELSE 0 END
            + CASE WHEN feat_support_per_order > 1 THEN 8 ELSE 0 END
            + CASE WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 12 ELSE 0 END
            + CASE WHEN feat_note_complaint_count >= 2 THEN 8 ELSE 0 END
            + CASE WHEN feat_gross_sales >= 20000 THEN -12 ELSE 0 END
            + CASE WHEN feat_margin_amount >= 5000 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_vip = 1 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_gold = 1 THEN -5 ELSE 0 END
            + CASE WHEN feat_marketing_positive_ratio >= 0.50 THEN -3 ELSE 0 END
        ) >= 80 THEN 'VERY_HIGH_RISK'
        WHEN (
            CASE WHEN feat_no_order_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_bad_payment_flag = 1 THEN 30 ELSE 0 END
            + CASE WHEN feat_high_return_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_support_pressure_flag = 1 THEN 20 ELSE 0 END
            + CASE WHEN feat_marketing_negative_flag = 1 THEN 10 ELSE 0 END
            + CASE WHEN feat_note_fraud_flag = 1 THEN 35 ELSE 0 END
            + CASE WHEN feat_payment_success_pct < 60 AND feat_payment_attempt_count > 0 THEN 15 ELSE 0 END
            + CASE WHEN feat_return_rate > 0.30 THEN 15 ELSE 0 END
            + CASE WHEN feat_support_per_order > 1 THEN 8 ELSE 0 END
            + CASE WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 12 ELSE 0 END
            + CASE WHEN feat_note_complaint_count >= 2 THEN 8 ELSE 0 END
            + CASE WHEN feat_gross_sales >= 20000 THEN -12 ELSE 0 END
            + CASE WHEN feat_margin_amount >= 5000 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_vip = 1 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_gold = 1 THEN -5 ELSE 0 END
            + CASE WHEN feat_marketing_positive_ratio >= 0.50 THEN -3 ELSE 0 END
        ) >= 55 THEN 'HIGH_RISK'
        WHEN (
            CASE WHEN feat_no_order_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_bad_payment_flag = 1 THEN 30 ELSE 0 END
            + CASE WHEN feat_high_return_flag = 1 THEN 25 ELSE 0 END
            + CASE WHEN feat_support_pressure_flag = 1 THEN 20 ELSE 0 END
            + CASE WHEN feat_marketing_negative_flag = 1 THEN 10 ELSE 0 END
            + CASE WHEN feat_note_fraud_flag = 1 THEN 35 ELSE 0 END
            + CASE WHEN feat_payment_success_pct < 60 AND feat_payment_attempt_count > 0 THEN 15 ELSE 0 END
            + CASE WHEN feat_return_rate > 0.30 THEN 15 ELSE 0 END
            + CASE WHEN feat_support_per_order > 1 THEN 8 ELSE 0 END
            + CASE WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 12 ELSE 0 END
            + CASE WHEN feat_note_complaint_count >= 2 THEN 8 ELSE 0 END
            + CASE WHEN feat_gross_sales >= 20000 THEN -12 ELSE 0 END
            + CASE WHEN feat_margin_amount >= 5000 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_vip = 1 THEN -10 ELSE 0 END
            + CASE WHEN ohe_class_gold = 1 THEN -5 ELSE 0 END
            + CASE WHEN feat_marketing_positive_ratio >= 0.50 THEN -3 ELSE 0 END
        ) >= 30 THEN 'MEDIUM_RISK'
        ELSE 'LOW_RISK'
    END AS sql_model_risk_bucket,
    CONCAT(
        'orders=', feat_total_orders,
        '|payment_pct=', feat_payment_success_pct,
        '|return_rate=', feat_return_rate,
        '|support_per_order=', feat_support_per_order,
        '|fraud_note=', feat_note_fraud_count,
        '|margin_ratio=', feat_margin_ratio
    ) AS sql_model_reason_blob,
    CURRENT_TIMESTAMP AS scored_at
FROM feature_layer.customer_model_feature_matrix_legacy;

CREATE UNIQUE INDEX IF NOT EXISTS ux_customer_sql_score_output ON model_layer.customer_sql_score_model_output(customer_id);
CREATE INDEX IF NOT EXISTS ix_customer_sql_score_bucket ON model_layer.customer_sql_score_model_output(sql_model_risk_bucket);
CREATE INDEX IF NOT EXISTS ix_customer_sql_score_score ON model_layer.customer_sql_score_model_output(sql_model_risk_score);

-- ============================================================================
-- 13. MODEL EVALUATION IN SQL
-- ============================================================================

DROP TABLE IF EXISTS model_layer.customer_sql_model_confusion_matrix;

CREATE TABLE model_layer.customer_sql_model_confusion_matrix AS
SELECT
    label_customer_risk AS actual_label,
    CASE WHEN sql_model_risk_score >= 55 THEN 1 ELSE 0 END AS predicted_label,
    COUNT(*) AS row_count
FROM model_layer.customer_sql_score_model_output
GROUP BY
    label_customer_risk,
    CASE WHEN sql_model_risk_score >= 55 THEN 1 ELSE 0 END;

DROP TABLE IF EXISTS model_layer.customer_sql_model_metrics;

CREATE TABLE model_layer.customer_sql_model_metrics AS
WITH cm AS (
    SELECT
        SUM(CASE WHEN actual_label = 1 AND predicted_label = 1 THEN row_count ELSE 0 END) AS tp,
        SUM(CASE WHEN actual_label = 0 AND predicted_label = 0 THEN row_count ELSE 0 END) AS tn,
        SUM(CASE WHEN actual_label = 0 AND predicted_label = 1 THEN row_count ELSE 0 END) AS fp,
        SUM(CASE WHEN actual_label = 1 AND predicted_label = 0 THEN row_count ELSE 0 END) AS fn
    FROM model_layer.customer_sql_model_confusion_matrix
)
SELECT
    tp,
    tn,
    fp,
    fn,
    ROUND((tp + tn) * 1.0 / NULLIF(tp + tn + fp + fn, 0), 4) AS accuracy,
    ROUND(tp * 1.0 / NULLIF(tp + fp, 0), 4) AS precision,
    ROUND(tp * 1.0 / NULLIF(tp + fn, 0), 4) AS recall,
    ROUND((2 * tp) * 1.0 / NULLIF((2 * tp + fp + fn), 0), 4) AS f1_score,
    CURRENT_TIMESTAMP AS evaluated_at
FROM cm;

-- ============================================================================
-- 14. OPTIONAL DATABASE ML EXTENSION STYLE SECTION
-- ============================================================================
-- This section is commented because not every database has ML extensions.
-- Some companies use MADlib, BigQuery ML, Snowflake ML, Oracle ML, or SAS.
--
-- Example only:
-- SELECT madlib.logregr_train(
--     'feature_layer.customer_model_feature_matrix_legacy',
--     'model_layer.madlib_customer_risk_model',
--     'label_customer_risk',
--     'ARRAY[
--         feat_total_orders,
--         feat_good_orders,
--         feat_bad_orders,
--         feat_gross_sales,
--         feat_margin_amount,
--         feat_payment_success_pct,
--         feat_real_return_count,
--         feat_support_open_count,
--         feat_marketing_negative_count,
--         feat_note_fraud_count,
--         feat_avg_order_value,
--         feat_margin_ratio,
--         feat_return_rate,
--         feat_support_per_order,
--         ohe_region_apac, ohe_region_emea, ohe_region_amer,
--         ohe_class_vip, ohe_class_gold, ohe_class_risk
--     ]'
-- );

-- ============================================================================
-- 15. REPORTING VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW report_layer.v_customer_model_ready_report AS
SELECT
    f.customer_id,
    f.customer_code,
    f.customer_name,
    f.region_clean,
    f.country_clean,
    f.class_clean,
    f.feat_total_orders,
    f.feat_gross_sales,
    f.feat_margin_amount,
    f.feat_payment_success_pct,
    f.feat_return_rate,
    f.feat_support_per_order,
    f.feat_marketing_positive_ratio,
    f.label_customer_risk,
    s.sql_model_risk_score,
    s.sql_model_risk_bucket,
    s.sql_model_reason_blob
FROM feature_layer.customer_model_feature_matrix_legacy f
LEFT JOIN model_layer.customer_sql_score_model_output s
    ON s.customer_id = f.customer_id;

CREATE OR REPLACE VIEW report_layer.v_distribution_graph_input AS
SELECT
    'NUMERIC' AS distribution_type,
    feature_name,
    bucket_no::TEXT AS x_value,
    row_count
FROM plot_layer.customer_numeric_distribution_long
UNION ALL
SELECT
    'CATEGORICAL' AS distribution_type,
    feature_name,
    category_value AS x_value,
    row_count
FROM plot_layer.customer_categorical_distribution_long;

-- ============================================================================
-- 16. DATA QUALITY CHECKS
-- ============================================================================

-- dq_customer_missing_code
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE customer_code = 'NO_CODE';

-- dq_customer_missing_email
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE email_clean = 'missing-email';

-- dq_customer_unknown_region
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE region_clean = 'UNKNOWN_REGION';

-- dq_negative_sales
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE feat_gross_sales < 0;

-- dq_negative_margin
SELECT COUNT(*) AS possible_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE feat_margin_amount < 0;

-- dq_payment_pct_over_100
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE feat_payment_success_pct > 100;

-- dq_return_rate_over_1
SELECT COUNT(*) AS possible_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE feat_return_rate > 1;

-- dq_missing_label
SELECT COUNT(*) AS bad_rows FROM feature_layer.customer_model_feature_matrix_legacy WHERE label_customer_risk IS NULL;

-- ============================================================================
-- 17. ANALYZE TABLES
-- ============================================================================

ANALYZE stage_layer.tmp_customer_clean_extract;
ANALYZE stage_layer.tmp_customer_class_extract;
ANALYZE stage_layer.tmp_order_line_extract;
ANALYZE stage_layer.tmp_order_level_preprocessed;
ANALYZE feature_layer.tmp_order_features;
ANALYZE feature_layer.tmp_payment_features;
ANALYZE feature_layer.tmp_return_features;
ANALYZE feature_layer.tmp_support_features;
ANALYZE feature_layer.tmp_marketing_features;
ANALYZE feature_layer.tmp_note_features;
ANALYZE feature_layer.customer_model_feature_matrix_legacy;
ANALYZE plot_layer.customer_numeric_distribution_long;
ANALYZE plot_layer.customer_categorical_distribution_long;
ANALYZE model_layer.customer_sql_score_model_output;
ANALYZE model_layer.customer_sql_model_confusion_matrix;
ANALYZE model_layer.customer_sql_model_metrics;

-- ============================================================================
-- 18. FINAL SELECTS
-- ============================================================================

SELECT * FROM model_layer.customer_sql_model_metrics;

SELECT
    sql_model_risk_bucket,
    COUNT(*) AS customer_count,
    ROUND(AVG(sql_model_risk_score), 4) AS avg_score
FROM model_layer.customer_sql_score_model_output
GROUP BY sql_model_risk_bucket
ORDER BY avg_score DESC;

SELECT
    feature_name,
    bucket_no,
    bucket_min,
    bucket_max,
    row_count
FROM plot_layer.customer_numeric_distribution_long
ORDER BY feature_name, bucket_no;

SELECT
    feature_name,
    category_value,
    row_count
FROM plot_layer.customer_categorical_distribution_long
ORDER BY feature_name, row_count DESC;

INSERT INTO audit_layer.legacy_sql_run_log(script_name, step_name, status, message)
VALUES ('legacy_sql_db_to_model_pipeline.sql', 'END_SCRIPT', 'FINISHED', 'SQL-only database to model pipeline finished');

-- ============================================================================
-- 19. EXTRA LEGACY WRAPPER VIEWS
-- ============================================================================
-- Old enterprise scripts sometimes contain many extra views that are not really
-- necessary but are kept because other dashboards or old jobs may depend on them.

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_01 AS
SELECT
    1 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 1 = 1;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_02 AS
SELECT
    2 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 2 = 2;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_03 AS
SELECT
    3 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 3 = 3;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_04 AS
SELECT
    4 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 4 = 4;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_05 AS
SELECT
    5 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 5 = 5;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_06 AS
SELECT
    6 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 6 = 6;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_07 AS
SELECT
    7 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 7 = 7;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_08 AS
SELECT
    8 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 8 = 8;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_09 AS
SELECT
    9 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 9 = 9;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_10 AS
SELECT
    10 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 10 = 10;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_11 AS
SELECT
    11 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 11 = 11;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_12 AS
SELECT
    12 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 12 = 12;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_13 AS
SELECT
    13 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 13 = 13;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_14 AS
SELECT
    14 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 14 = 14;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_15 AS
SELECT
    15 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 15 = 15;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_16 AS
SELECT
    16 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 16 = 16;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_17 AS
SELECT
    17 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 17 = 17;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_18 AS
SELECT
    18 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 18 = 18;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_19 AS
SELECT
    19 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 19 = 19;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_20 AS
SELECT
    20 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 20 = 20;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_21 AS
SELECT
    21 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 21 = 21;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_22 AS
SELECT
    22 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 22 = 22;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_23 AS
SELECT
    23 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 23 = 23;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_24 AS
SELECT
    24 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 24 = 24;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_25 AS
SELECT
    25 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 25 = 25;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_26 AS
SELECT
    26 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 26 = 26;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_27 AS
SELECT
    27 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 27 = 27;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_28 AS
SELECT
    28 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 28 = 28;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_29 AS
SELECT
    29 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 29 = 29;

CREATE OR REPLACE VIEW report_layer.v_legacy_customer_score_wrapper_30 AS
SELECT
    30 AS wrapper_version,
    customer_id,
    customer_code,
    customer_name,
    region_clean,
    class_clean,
    feat_total_orders,
    feat_gross_sales,
    feat_margin_amount,
    feat_payment_success_pct,
    feat_return_rate,
    feat_support_per_order,
    label_customer_risk,
    sql_model_risk_score,
    sql_model_risk_bucket,
    CASE
        WHEN sql_model_risk_bucket IN ('VERY_HIGH_RISK', 'HIGH_RISK') THEN 'SEND_TO_REVIEW_QUEUE'
        WHEN sql_model_risk_bucket = 'MEDIUM_RISK' THEN 'MONITOR_ONLY'
        ELSE 'NO_ACTION'
    END AS operational_action
FROM report_layer.v_customer_model_ready_report
WHERE 30 = 30;

-- ============================================================================
-- 20. LEGACY CHANGE NOTES
-- ============================================================================


-- ============================================================================
-- END OF SQL FILE
-- ============================================================================
