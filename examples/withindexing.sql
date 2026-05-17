/*
================================================================================
 EXTREMELY LONG LEGACY SQL SCRIPT
 Dialect: PostgreSQL / psql style
 Includes connection commands, schemas, raw tables, indexes, staging views,
 feature engineering, one-hot encoding, materialized feature store, snapshots,
 QA checks, wrapper views, and one oversized report function.
 Original mock SQL for practice, not copied from any company system.
================================================================================
*/

-- ============================================================================
-- 00. DATABASE AND CONNECTION SETUP
-- ============================================================================
CREATE DATABASE legacy_confusing_dw;
\connect legacy_confusing_dw
SET client_min_messages = WARNING;
SET timezone = 'Asia/Kuala_Lumpur';
SET search_path = public;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET idle_in_transaction_session_timeout = '0';
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS tablefunc;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'legacy_batch_user') THEN
        CREATE ROLE legacy_batch_user LOGIN PASSWORD 'change_me_in_real_system';
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS raw_layer;
GRANT USAGE ON SCHEMA raw_layer TO legacy_batch_user;
CREATE SCHEMA IF NOT EXISTS stage_layer;
GRANT USAGE ON SCHEMA stage_layer TO legacy_batch_user;
CREATE SCHEMA IF NOT EXISTS feature_layer;
GRANT USAGE ON SCHEMA feature_layer TO legacy_batch_user;
CREATE SCHEMA IF NOT EXISTS report_layer;
GRANT USAGE ON SCHEMA report_layer TO legacy_batch_user;
CREATE SCHEMA IF NOT EXISTS audit_layer;
GRANT USAGE ON SCHEMA audit_layer TO legacy_batch_user;

-- ============================================================================
-- 01. RAW TABLE DEFINITIONS
-- ============================================================================
CREATE TABLE IF NOT EXISTS raw_layer.z_customer_master_legacy (
    c_id BIGINT PRIMARY KEY,
    c_code VARCHAR(40),
    c_full_name VARCHAR(255),
    c_email VARCHAR(255),
    c_region VARCHAR(80),
    c_country VARCHAR(80),
    c_gender VARCHAR(40),
    c_age_band VARCHAR(40),
    c_created_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    c_updated_on TIMESTAMP,
    c_deleted_flag CHAR(1) NOT NULL DEFAULT 'N',
    c_source_system VARCHAR(80)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_customer_class_history_legacy (
    h_id BIGINT PRIMARY KEY,
    h_customer_id BIGINT NOT NULL,
    h_class_code VARCHAR(50),
    h_class_label VARCHAR(100),
    h_valid_from DATE NOT NULL,
    h_valid_to DATE,
    h_is_manual_override CHAR(1) DEFAULT 'N',
    h_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (h_customer_id) REFERENCES raw_layer.z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_product_dictionary_legacy (
    p_id BIGINT PRIMARY KEY,
    p_sku VARCHAR(80),
    p_name VARCHAR(255),
    p_family VARCHAR(100),
    p_category VARCHAR(100),
    p_cost NUMERIC(14, 4),
    p_list_price NUMERIC(14, 4),
    p_enabled_flag CHAR(1) DEFAULT 'Y',
    p_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw_layer.z_sales_order_header_legacy (
    oh_id BIGINT PRIMARY KEY,
    oh_customer_id BIGINT NOT NULL,
    oh_order_no VARCHAR(80),
    oh_order_ts TIMESTAMP NOT NULL,
    oh_status VARCHAR(40),
    oh_discount_total NUMERIC(14, 4) DEFAULT 0,
    oh_shipping_total NUMERIC(14, 4) DEFAULT 0,
    oh_tax_total NUMERIC(14, 4) DEFAULT 0,
    oh_source_channel VARCHAR(80),
    oh_currency VARCHAR(20),
    oh_created_by VARCHAR(80),
    FOREIGN KEY (oh_customer_id) REFERENCES raw_layer.z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_sales_order_line_legacy (
    ol_id BIGINT PRIMARY KEY,
    ol_order_id BIGINT NOT NULL,
    ol_product_id BIGINT NOT NULL,
    ol_qty NUMERIC(14, 4),
    ol_unit_price NUMERIC(14, 4),
    ol_line_status VARCHAR(40),
    ol_created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ol_order_id) REFERENCES raw_layer.z_sales_order_header_legacy(oh_id),
    FOREIGN KEY (ol_product_id) REFERENCES raw_layer.z_product_dictionary_legacy(p_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_payment_attempt_legacy (
    pay_id BIGINT PRIMARY KEY,
    pay_order_id BIGINT NOT NULL,
    pay_status VARCHAR(40),
    pay_method VARCHAR(80),
    pay_amount NUMERIC(14, 4),
    pay_created_ts TIMESTAMP,
    pay_captured_ts TIMESTAMP,
    pay_gateway_ref VARCHAR(255),
    pay_failure_code VARCHAR(80),
    FOREIGN KEY (pay_order_id) REFERENCES raw_layer.z_sales_order_header_legacy(oh_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_return_case_legacy (
    r_id BIGINT PRIMARY KEY,
    r_order_id BIGINT NOT NULL,
    r_status VARCHAR(40),
    r_reason_code VARCHAR(80),
    r_created_ts TIMESTAMP NOT NULL,
    r_closed_ts TIMESTAMP,
    r_refund_amount NUMERIC(14, 4),
    r_handler VARCHAR(80),
    FOREIGN KEY (r_order_id) REFERENCES raw_layer.z_sales_order_header_legacy(oh_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_support_case_legacy (
    s_id BIGINT PRIMARY KEY,
    s_customer_id BIGINT NOT NULL,
    s_status VARCHAR(40),
    s_priority VARCHAR(40),
    s_topic VARCHAR(120),
    s_created_ts TIMESTAMP NOT NULL,
    s_closed_ts TIMESTAMP,
    s_agent_group VARCHAR(80),
    FOREIGN KEY (s_customer_id) REFERENCES raw_layer.z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_marketing_touch_legacy (
    m_id BIGINT PRIMARY KEY,
    m_customer_id BIGINT NOT NULL,
    m_touch_type VARCHAR(80),
    m_campaign_code VARCHAR(120),
    m_touch_ts TIMESTAMP NOT NULL,
    m_cost NUMERIC(14, 4),
    m_channel VARCHAR(80),
    FOREIGN KEY (m_customer_id) REFERENCES raw_layer.z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS raw_layer.z_customer_note_legacy (
    n_id BIGINT PRIMARY KEY,
    n_customer_id BIGINT NOT NULL,
    n_note_type VARCHAR(80),
    n_note_text TEXT,
    n_created_ts TIMESTAMP NOT NULL,
    n_created_by VARCHAR(80),
    FOREIGN KEY (n_customer_id) REFERENCES raw_layer.z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS audit_layer.z_batch_run_log_legacy (
    run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_name VARCHAR(255),
    run_status VARCHAR(40),
    start_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_ts TIMESTAMP,
    rows_processed BIGINT,
    message TEXT
);

-- ============================================================================
-- 02. INDEXING SECTION
-- ============================================================================
CREATE INDEX IF NOT EXISTS ix_cust_region_deleted ON raw_layer.z_customer_master_legacy(c_region, c_deleted_flag);
CREATE INDEX IF NOT EXISTS ix_cust_created ON raw_layer.z_customer_master_legacy(c_created_on);
CREATE INDEX IF NOT EXISTS ix_cust_country_region ON raw_layer.z_customer_master_legacy(c_country, c_region);
CREATE INDEX IF NOT EXISTS ix_class_customer_valid ON raw_layer.z_customer_class_history_legacy(h_customer_id, h_valid_from, h_valid_to);
CREATE INDEX IF NOT EXISTS ix_class_manual_override ON raw_layer.z_customer_class_history_legacy(h_customer_id, h_is_manual_override);
CREATE INDEX IF NOT EXISTS ix_prod_family_category ON raw_layer.z_product_dictionary_legacy(p_family, p_category);
CREATE INDEX IF NOT EXISTS ix_prod_enabled ON raw_layer.z_product_dictionary_legacy(p_enabled_flag);
CREATE INDEX IF NOT EXISTS ix_order_customer_ts ON raw_layer.z_sales_order_header_legacy(oh_customer_id, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_order_status_ts ON raw_layer.z_sales_order_header_legacy(oh_status, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_order_channel_ts ON raw_layer.z_sales_order_header_legacy(oh_source_channel, oh_order_ts);
CREATE INDEX IF NOT EXISTS ix_order_line_order ON raw_layer.z_sales_order_line_legacy(ol_order_id);
CREATE INDEX IF NOT EXISTS ix_order_line_product ON raw_layer.z_sales_order_line_legacy(ol_product_id);
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
CREATE INDEX IF NOT EXISTS ix_note_type_ts ON raw_layer.z_customer_note_legacy(n_note_type, n_created_ts);
CREATE INDEX IF NOT EXISTS ix_order_open_partial ON raw_layer.z_sales_order_header_legacy(oh_customer_id, oh_order_ts) WHERE oh_status NOT IN ('DRAFT', 'TEST', 'SANDBOX');
CREATE INDEX IF NOT EXISTS ix_payment_success_partial ON raw_layer.z_payment_attempt_legacy(pay_order_id, pay_captured_ts) WHERE pay_status IN ('SUCCESS', 'CAPTURED', 'SETTLED');
CREATE INDEX IF NOT EXISTS ix_support_open_partial ON raw_layer.z_support_case_legacy(s_customer_id, s_created_ts) WHERE s_status NOT IN ('CLOSED', 'RESOLVED');
CREATE INDEX IF NOT EXISTS ix_customer_lower_email_expr ON raw_layer.z_customer_master_legacy(LOWER(c_email));

-- ============================================================================
-- 03. STAGING VIEWS
-- ============================================================================
CREATE OR REPLACE VIEW stage_layer.v_customer_clean_legacy AS
SELECT
    c.c_id,
    NULLIF(TRIM(c.c_code), '') AS c_code,
    COALESCE(NULLIF(TRIM(c.c_full_name), ''), 'UNKNOWN CUSTOMER') AS customer_name_clean,
    LOWER(COALESCE(NULLIF(TRIM(c.c_email), ''), 'missing-email')) AS email_clean,
    COALESCE(NULLIF(TRIM(c.c_region), ''), 'UNKNOWN_REGION') AS region_clean,
    COALESCE(NULLIF(TRIM(c.c_country), ''), 'UNKNOWN_COUNTRY') AS country_clean,
    COALESCE(NULLIF(TRIM(c.c_gender), ''), 'UNKNOWN_GENDER') AS gender_clean,
    COALESCE(NULLIF(TRIM(c.c_age_band), ''), 'UNKNOWN_AGE') AS age_band_clean,
    c.c_created_on,
    c.c_updated_on,
    c.c_deleted_flag,
    EXTRACT(DAY FROM CURRENT_TIMESTAMP - c.c_created_on) AS account_age_days,
    CASE WHEN c.c_deleted_flag = 'Y' THEN 1 ELSE 0 END AS deleted_flag_num
FROM raw_layer.z_customer_master_legacy c
WHERE COALESCE(c.c_deleted_flag, 'N') <> 'Y';

CREATE OR REPLACE VIEW stage_layer.v_order_line_clean_legacy AS
SELECT
    h.oh_id,
    h.oh_customer_id,
    h.oh_order_no,
    h.oh_order_ts,
    COALESCE(h.oh_status, 'UNKNOWN_STATUS') AS order_status_clean,
    COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') AS source_channel_clean,
    COALESCE(h.oh_currency, 'UNKNOWN_CURRENCY') AS currency_clean,
    COALESCE(h.oh_discount_total, 0) AS discount_total_clean,
    COALESCE(h.oh_shipping_total, 0) AS shipping_total_clean,
    COALESCE(h.oh_tax_total, 0) AS tax_total_clean,
    l.ol_id,
    l.ol_product_id,
    COALESCE(l.ol_qty, 0) AS qty_clean,
    COALESCE(l.ol_unit_price, 0) AS unit_price_clean,
    COALESCE(l.ol_line_status, 'UNKNOWN_LINE_STATUS') AS line_status_clean,
    COALESCE(p.p_family, 'UNKNOWN_FAMILY') AS product_family_clean,
    COALESCE(p.p_category, 'UNKNOWN_CATEGORY') AS product_category_clean,
    COALESCE(p.p_cost, 0) AS product_cost_clean,
    CASE WHEN COALESCE(l.ol_line_status, 'OK') IN ('VOID', 'CANCELLED') THEN 0 ELSE 1 END AS active_line_flag,
    COALESCE(l.ol_qty, 0) * COALESCE(l.ol_unit_price, 0) AS line_gross_amount,
    COALESCE(l.ol_qty, 0) * COALESCE(p.p_cost, 0) AS line_cost_amount
FROM raw_layer.z_sales_order_header_legacy h
LEFT JOIN raw_layer.z_sales_order_line_legacy l ON h.oh_id = l.ol_order_id
LEFT JOIN raw_layer.z_product_dictionary_legacy p ON l.ol_product_id = p.p_id
WHERE COALESCE(h.oh_status, 'UNKNOWN') NOT IN ('DRAFT', 'TEST', 'SANDBOX');

-- ============================================================================
-- 04. FEATURE ENGINEERING VIEW WITH ONE-HOT ENCODING
-- ============================================================================
CREATE OR REPLACE VIEW feature_layer.v_customer_feature_engineering_legacy AS
WITH
base_customer AS (
    SELECT
        c.c_id,
        c.c_code,
        c.customer_name_clean,
        c.email_clean,
        c.region_clean,
        c.country_clean,
        c.gender_clean,
        c.age_band_clean,
        c.account_age_days,
        CASE WHEN c.account_age_days <= 30 THEN 1 ELSE 0 END AS feat_account_new_30d,
        CASE WHEN c.account_age_days BETWEEN 31 AND 180 THEN 1 ELSE 0 END AS feat_account_mid_31_180d,
        CASE WHEN c.account_age_days > 180 THEN 1 ELSE 0 END AS feat_account_old_180d_plus
    FROM stage_layer.v_customer_clean_legacy c
),
class_one AS (
    SELECT t.h_customer_id, COALESCE(t.h_class_label, t.h_class_code, 'NO_CLASS') AS class_clean, CASE WHEN t.h_is_manual_override = 'Y' THEN 1 ELSE 0 END AS class_manual_override_flag
    FROM (
        SELECT h.*, ROW_NUMBER() OVER (PARTITION BY h.h_customer_id ORDER BY CASE WHEN h.h_is_manual_override = 'Y' THEN 0 ELSE 1 END, h.h_valid_from DESC, h.h_id DESC) AS rn
        FROM raw_layer.z_customer_class_history_legacy h
        WHERE h.h_valid_from <= CURRENT_DATE AND COALESCE(h.h_valid_to, DATE '2999-12-31') >= CURRENT_DATE
    ) t WHERE t.rn = 1
),
order_agg AS (
    SELECT
        ol.oh_customer_id,
        COUNT(DISTINCT ol.oh_id) AS feat_total_orders,
        COUNT(DISTINCT CASE WHEN ol.order_status_clean IN ('COMPLETED', 'SHIPPED', 'DELIVERED') THEN ol.oh_id END) AS feat_good_orders,
        COUNT(DISTINCT CASE WHEN ol.order_status_clean IN ('CANCELLED', 'FAILED', 'VOID') THEN ol.oh_id END) AS feat_bad_orders,
        SUM(CASE WHEN ol.active_line_flag = 1 THEN ol.qty_clean ELSE 0 END) AS feat_total_units,
        SUM(CASE WHEN ol.active_line_flag = 1 THEN ol.line_gross_amount ELSE 0 END) AS feat_gross_sales,
        SUM(CASE WHEN ol.active_line_flag = 1 THEN ol.line_cost_amount ELSE 0 END) AS feat_cost_amount,
        SUM(CASE WHEN ol.active_line_flag = 1 THEN ol.line_gross_amount - ol.line_cost_amount ELSE 0 END) AS feat_margin_amount,
        AVG(CASE WHEN ol.active_line_flag = 1 THEN ol.line_gross_amount ELSE NULL END) AS feat_avg_line_amount,
        MAX(ol.oh_order_ts) AS feat_last_order_ts,
        MIN(ol.oh_order_ts) AS feat_first_order_ts,
        SUM(CASE WHEN ol.product_family_clean = 'PREMIUM' THEN 1 ELSE 0 END) AS feat_premium_line_cnt,
        SUM(CASE WHEN ol.product_family_clean = 'ENTERPRISE' THEN 1 ELSE 0 END) AS feat_enterprise_line_cnt,
        SUM(CASE WHEN ol.product_family_clean = 'BASIC' THEN 1 ELSE 0 END) AS feat_basic_line_cnt,
        SUM(CASE WHEN ol.source_channel_clean = 'DIRECT' THEN 1 ELSE 0 END) AS feat_channel_direct_cnt,
        SUM(CASE WHEN ol.source_channel_clean = 'STORE' THEN 1 ELSE 0 END) AS feat_channel_store_cnt,
        SUM(CASE WHEN ol.source_channel_clean = 'AFFILIATE' THEN 1 ELSE 0 END) AS feat_channel_affiliate_cnt,
        SUM(CASE WHEN ol.source_channel_clean = 'MARKETPLACE' THEN 1 ELSE 0 END) AS feat_channel_marketplace_cnt
    FROM stage_layer.v_order_line_clean_legacy ol GROUP BY ol.oh_customer_id
),
payment_agg AS (
    SELECT
        h.oh_customer_id,
        COUNT(*) AS feat_payment_attempt_cnt,
        SUM(CASE WHEN p.pay_status IN ('SUCCESS', 'CAPTURED', 'SETTLED') THEN 1 ELSE 0 END) AS feat_payment_success_cnt,
        SUM(CASE WHEN p.pay_status IN ('FAILED', 'DECLINED', 'REVERSED') THEN 1 ELSE 0 END) AS feat_payment_failed_cnt,
        SUM(CASE WHEN p.pay_method = 'CARD' THEN 1 ELSE 0 END) AS feat_pay_method_card_cnt,
        SUM(CASE WHEN p.pay_method = 'BANK_TRANSFER' THEN 1 ELSE 0 END) AS feat_pay_method_bank_cnt,
        SUM(CASE WHEN p.pay_method = 'WALLET' THEN 1 ELSE 0 END) AS feat_pay_method_wallet_cnt,
        MAX(COALESCE(p.pay_captured_ts, p.pay_created_ts)) AS feat_last_payment_ts
    FROM raw_layer.z_payment_attempt_legacy p INNER JOIN raw_layer.z_sales_order_header_legacy h ON p.pay_order_id = h.oh_id GROUP BY h.oh_customer_id
),
return_agg AS (
    SELECT
        h.oh_customer_id,
        COUNT(*) AS feat_return_cnt,
        SUM(CASE WHEN r.r_status IN ('APPROVED', 'REFUNDED', 'PARTIAL_REFUND') THEN 1 ELSE 0 END) AS feat_real_return_cnt,
        SUM(CASE WHEN r.r_reason_code = 'DAMAGED' THEN 1 ELSE 0 END) AS feat_return_damaged_cnt,
        SUM(CASE WHEN r.r_reason_code = 'WRONG_ITEM' THEN 1 ELSE 0 END) AS feat_return_wrong_item_cnt,
        SUM(CASE WHEN r.r_reason_code = 'CHANGE_MIND' THEN 1 ELSE 0 END) AS feat_return_change_mind_cnt,
        SUM(COALESCE(r.r_refund_amount, 0)) AS feat_refund_amount,
        MAX(COALESCE(r.r_closed_ts, r.r_created_ts)) AS feat_last_return_ts
    FROM raw_layer.z_return_case_legacy r INNER JOIN raw_layer.z_sales_order_header_legacy h ON r.r_order_id = h.oh_id GROUP BY h.oh_customer_id
),
support_agg AS (
    SELECT
        s.s_customer_id,
        COUNT(*) AS feat_support_cnt,
        SUM(CASE WHEN s.s_status NOT IN ('CLOSED', 'RESOLVED') THEN 1 ELSE 0 END) AS feat_support_open_cnt,
        SUM(CASE WHEN s.s_priority IN ('HIGH', 'URGENT', 'CRITICAL') THEN 1 ELSE 0 END) AS feat_support_high_cnt,
        SUM(CASE WHEN s.s_topic = 'PAYMENT' THEN 1 ELSE 0 END) AS feat_support_payment_cnt,
        SUM(CASE WHEN s.s_topic = 'DELIVERY' THEN 1 ELSE 0 END) AS feat_support_delivery_cnt,
        SUM(CASE WHEN s.s_topic = 'PRODUCT' THEN 1 ELSE 0 END) AS feat_support_product_cnt,
        MAX(COALESCE(s.s_closed_ts, s.s_created_ts)) AS feat_last_support_ts
    FROM raw_layer.z_support_case_legacy s GROUP BY s.s_customer_id
),
marketing_agg AS (
    SELECT
        m.m_customer_id,
        COUNT(*) AS feat_marketing_touch_cnt,
        SUM(CASE WHEN m.m_touch_type IN ('EMAIL_OPEN', 'EMAIL_CLICK', 'AD_CLICK', 'PUSH_CLICK') THEN 1 ELSE 0 END) AS feat_marketing_positive_cnt,
        SUM(CASE WHEN m.m_touch_type IN ('UNSUBSCRIBE', 'SPAM_REPORT') THEN 1 ELSE 0 END) AS feat_marketing_negative_cnt,
        SUM(CASE WHEN m.m_channel = 'EMAIL' THEN 1 ELSE 0 END) AS feat_mkt_email_cnt,
        SUM(CASE WHEN m.m_channel = 'PUSH' THEN 1 ELSE 0 END) AS feat_mkt_push_cnt,
        SUM(CASE WHEN m.m_channel = 'AD' THEN 1 ELSE 0 END) AS feat_mkt_ad_cnt,
        SUM(COALESCE(m.m_cost, 0)) AS feat_marketing_cost,
        MAX(m.m_touch_ts) AS feat_last_marketing_ts
    FROM raw_layer.z_marketing_touch_legacy m GROUP BY m.m_customer_id
),
note_agg AS (
    SELECT
        n.n_customer_id,
        COUNT(*) AS feat_note_cnt,
        SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%fraud%' THEN 1 ELSE 0 END) AS feat_note_fraud_word_cnt,
        SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%angry%' THEN 1 ELSE 0 END) AS feat_note_angry_word_cnt,
        SUM(CASE WHEN LOWER(COALESCE(n.n_note_text, '')) LIKE '%vip%' THEN 1 ELSE 0 END) AS feat_note_vip_word_cnt,
        MAX(n.n_created_ts) AS feat_last_note_ts
    FROM raw_layer.z_customer_note_legacy n GROUP BY n.n_customer_id
)
SELECT
    bc.c_id AS customer_id,
    bc.c_code AS customer_code,
    bc.customer_name_clean,
    bc.email_clean,
    bc.region_clean,
    bc.country_clean,
    bc.gender_clean,
    bc.age_band_clean,
    COALESCE(co.class_clean, 'NO_CLASS') AS class_clean,
    COALESCE(co.class_manual_override_flag, 0) AS feat_class_manual_override_flag,
    bc.account_age_days,
    bc.feat_account_new_30d,
    bc.feat_account_mid_31_180d,
    bc.feat_account_old_180d_plus,
    COALESCE(oa.feat_total_orders, 0) AS feat_total_orders,
    COALESCE(oa.feat_good_orders, 0) AS feat_good_orders,
    COALESCE(oa.feat_bad_orders, 0) AS feat_bad_orders,
    COALESCE(oa.feat_total_units, 0) AS feat_total_units,
    COALESCE(oa.feat_gross_sales, 0) AS feat_gross_sales,
    COALESCE(oa.feat_cost_amount, 0) AS feat_cost_amount,
    COALESCE(oa.feat_margin_amount, 0) AS feat_margin_amount,
    COALESCE(oa.feat_avg_line_amount, 0) AS feat_avg_line_amount,
    oa.feat_last_order_ts,
    oa.feat_first_order_ts,
    COALESCE(pa.feat_payment_attempt_cnt, 0) AS feat_payment_attempt_cnt,
    COALESCE(pa.feat_payment_success_cnt, 0) AS feat_payment_success_cnt,
    COALESCE(pa.feat_payment_failed_cnt, 0) AS feat_payment_failed_cnt,
    ROUND(CASE WHEN COALESCE(pa.feat_payment_attempt_cnt, 0) = 0 THEN 0 ELSE pa.feat_payment_success_cnt * 100.0 / NULLIF(pa.feat_payment_attempt_cnt, 0) END, 2) AS feat_payment_success_pct,
    COALESCE(ra.feat_return_cnt, 0) AS feat_return_cnt,
    COALESCE(ra.feat_real_return_cnt, 0) AS feat_real_return_cnt,
    COALESCE(ra.feat_refund_amount, 0) AS feat_refund_amount,
    COALESCE(sa.feat_support_cnt, 0) AS feat_support_cnt,
    COALESCE(sa.feat_support_open_cnt, 0) AS feat_support_open_cnt,
    COALESCE(sa.feat_support_high_cnt, 0) AS feat_support_high_cnt,
    COALESCE(ma.feat_marketing_touch_cnt, 0) AS feat_marketing_touch_cnt,
    COALESCE(ma.feat_marketing_positive_cnt, 0) AS feat_marketing_positive_cnt,
    COALESCE(ma.feat_marketing_negative_cnt, 0) AS feat_marketing_negative_cnt,
    COALESCE(na.feat_note_cnt, 0) AS feat_note_cnt,
    COALESCE(na.feat_note_fraud_word_cnt, 0) AS feat_note_fraud_word_cnt,
    COALESCE(na.feat_note_angry_word_cnt, 0) AS feat_note_angry_word_cnt,
    COALESCE(na.feat_note_vip_word_cnt, 0) AS feat_note_vip_word_cnt,
    GREATEST(COALESCE(oa.feat_last_order_ts, TIMESTAMP '1900-01-01'), COALESCE(pa.feat_last_payment_ts, TIMESTAMP '1900-01-01'), COALESCE(ra.feat_last_return_ts, TIMESTAMP '1900-01-01'), COALESCE(sa.feat_last_support_ts, TIMESTAMP '1900-01-01'), COALESCE(ma.feat_last_marketing_ts, TIMESTAMP '1900-01-01'), COALESCE(na.feat_last_note_ts, TIMESTAMP '1900-01-01')) AS feat_last_any_activity_ts,
    CASE WHEN UPPER(bc.region_clean) = 'APAC' THEN 1 ELSE 0 END AS ohe_region_apac,
    CASE WHEN UPPER(bc.region_clean) = 'EMEA' THEN 1 ELSE 0 END AS ohe_region_emea,
    CASE WHEN UPPER(bc.region_clean) = 'AMER' THEN 1 ELSE 0 END AS ohe_region_amer,
    CASE WHEN UPPER(bc.region_clean) = 'ASEAN' THEN 1 ELSE 0 END AS ohe_region_asean,
    CASE WHEN UPPER(bc.region_clean) = 'MALAYSIA' THEN 1 ELSE 0 END AS ohe_region_malaysia,
    CASE WHEN UPPER(bc.region_clean) = 'SINGAPORE' THEN 1 ELSE 0 END AS ohe_region_singapore,
    CASE WHEN UPPER(bc.region_clean) = 'THAILAND' THEN 1 ELSE 0 END AS ohe_region_thailand,
    CASE WHEN UPPER(bc.region_clean) = 'CHINA' THEN 1 ELSE 0 END AS ohe_region_china,
    CASE WHEN UPPER(bc.region_clean) = 'INDIA' THEN 1 ELSE 0 END AS ohe_region_india,
    CASE WHEN UPPER(bc.region_clean) = 'JAPAN' THEN 1 ELSE 0 END AS ohe_region_japan,
    CASE WHEN UPPER(bc.region_clean) = 'KOREA' THEN 1 ELSE 0 END AS ohe_region_korea,
    CASE WHEN UPPER(bc.region_clean) = 'EUROPE' THEN 1 ELSE 0 END AS ohe_region_europe,
    CASE WHEN UPPER(bc.region_clean) = 'UNKNOWN_REGION' THEN 1 ELSE 0 END AS ohe_region_unknown_region,
    CASE WHEN UPPER(bc.country_clean) = 'MALAYSIA' THEN 1 ELSE 0 END AS ohe_country_malaysia,
    CASE WHEN UPPER(bc.country_clean) = 'SINGAPORE' THEN 1 ELSE 0 END AS ohe_country_singapore,
    CASE WHEN UPPER(bc.country_clean) = 'THAILAND' THEN 1 ELSE 0 END AS ohe_country_thailand,
    CASE WHEN UPPER(bc.country_clean) = 'CHINA' THEN 1 ELSE 0 END AS ohe_country_china,
    CASE WHEN UPPER(bc.country_clean) = 'INDIA' THEN 1 ELSE 0 END AS ohe_country_india,
    CASE WHEN UPPER(bc.country_clean) = 'JAPAN' THEN 1 ELSE 0 END AS ohe_country_japan,
    CASE WHEN UPPER(bc.country_clean) = 'KOREA' THEN 1 ELSE 0 END AS ohe_country_korea,
    CASE WHEN UPPER(bc.country_clean) = 'USA' THEN 1 ELSE 0 END AS ohe_country_usa,
    CASE WHEN UPPER(bc.country_clean) = 'GERMANY' THEN 1 ELSE 0 END AS ohe_country_germany,
    CASE WHEN UPPER(bc.country_clean) = 'UNKNOWN_COUNTRY' THEN 1 ELSE 0 END AS ohe_country_unknown_country,
    CASE WHEN UPPER(bc.gender_clean) = 'MALE' THEN 1 ELSE 0 END AS ohe_gender_male,
    CASE WHEN UPPER(bc.gender_clean) = 'FEMALE' THEN 1 ELSE 0 END AS ohe_gender_female,
    CASE WHEN UPPER(bc.gender_clean) = 'UNKNOWN_GENDER' THEN 1 ELSE 0 END AS ohe_gender_unknown_gender,
    CASE WHEN UPPER(bc.age_band_clean) = '18_25' THEN 1 ELSE 0 END AS ohe_age_18_25,
    CASE WHEN UPPER(bc.age_band_clean) = '26_35' THEN 1 ELSE 0 END AS ohe_age_26_35,
    CASE WHEN UPPER(bc.age_band_clean) = '36_45' THEN 1 ELSE 0 END AS ohe_age_36_45,
    CASE WHEN UPPER(bc.age_band_clean) = '46_55' THEN 1 ELSE 0 END AS ohe_age_46_55,
    CASE WHEN UPPER(bc.age_band_clean) = '56_PLUS' THEN 1 ELSE 0 END AS ohe_age_56_plus,
    CASE WHEN UPPER(bc.age_band_clean) = 'UNKNOWN_AGE' THEN 1 ELSE 0 END AS ohe_age_unknown_age,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'VIP' THEN 1 ELSE 0 END AS ohe_class_vip,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'GOLD' THEN 1 ELSE 0 END AS ohe_class_gold,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'SILVER' THEN 1 ELSE 0 END AS ohe_class_silver,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'BRONZE' THEN 1 ELSE 0 END AS ohe_class_bronze,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'RISK' THEN 1 ELSE 0 END AS ohe_class_risk,
    CASE WHEN UPPER(COALESCE(co.class_clean, 'NO_CLASS')) = 'NO_CLASS' THEN 1 ELSE 0 END AS ohe_class_no_class
FROM base_customer bc
LEFT JOIN class_one co ON co.h_customer_id = bc.c_id
LEFT JOIN order_agg oa ON oa.oh_customer_id = bc.c_id
LEFT JOIN payment_agg pa ON pa.oh_customer_id = bc.c_id
LEFT JOIN return_agg ra ON ra.oh_customer_id = bc.c_id
LEFT JOIN support_agg sa ON sa.s_customer_id = bc.c_id
LEFT JOIN marketing_agg ma ON ma.m_customer_id = bc.c_id
LEFT JOIN note_agg na ON na.n_customer_id = bc.c_id;

-- ============================================================================
-- 05. MATERIALIZED FEATURE STORE
-- ============================================================================
DROP MATERIALIZED VIEW IF EXISTS feature_layer.mv_customer_feature_store_legacy;
CREATE MATERIALIZED VIEW feature_layer.mv_customer_feature_store_legacy AS
SELECT
    *,
    CASE WHEN feat_total_orders = 0 THEN 1 ELSE 0 END AS feat_no_order_flag,
    CASE WHEN feat_payment_success_pct < 70 AND feat_payment_attempt_cnt > 0 THEN 1 ELSE 0 END AS feat_bad_payment_flag,
    CASE WHEN feat_real_return_cnt >= 3 THEN 1 ELSE 0 END AS feat_high_return_flag,
    CASE WHEN feat_support_open_cnt >= 5 THEN 1 ELSE 0 END AS feat_support_pressure_flag,
    CASE WHEN feat_marketing_negative_cnt >= 2 THEN 1 ELSE 0 END AS feat_marketing_negative_flag,
    CASE WHEN feat_note_fraud_word_cnt > 0 THEN 1 ELSE 0 END AS feat_note_fraud_flag,
    ROUND(CASE WHEN feat_total_orders = 0 THEN 0 ELSE feat_gross_sales / NULLIF(feat_total_orders, 0) END, 4) AS feat_avg_order_value,
    ROUND(CASE WHEN feat_gross_sales = 0 THEN 0 ELSE feat_margin_amount / NULLIF(feat_gross_sales, 0) END, 4) AS feat_margin_ratio,
    ROUND(CASE WHEN feat_total_orders = 0 THEN 0 ELSE feat_real_return_cnt * 1.0 / NULLIF(feat_total_orders, 0) END, 4) AS feat_return_rate,
    ROUND(CASE WHEN feat_total_orders = 0 THEN 0 ELSE feat_support_cnt * 1.0 / NULLIF(feat_total_orders, 0) END, 4) AS feat_support_per_order,
    ROUND(CASE WHEN feat_marketing_touch_cnt = 0 THEN 0 ELSE feat_marketing_positive_cnt * 1.0 / NULLIF(feat_marketing_touch_cnt, 0) END, 4) AS feat_marketing_positive_ratio,
    CURRENT_TIMESTAMP AS feature_refresh_ts
FROM feature_layer.v_customer_feature_engineering_legacy;
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_customer_feature_store_customer_id ON feature_layer.mv_customer_feature_store_legacy(customer_id);
CREATE INDEX IF NOT EXISTS ix_mv_customer_feature_store_region ON feature_layer.mv_customer_feature_store_legacy(region_clean);
CREATE INDEX IF NOT EXISTS ix_mv_customer_feature_store_class ON feature_layer.mv_customer_feature_store_legacy(class_clean);
CREATE INDEX IF NOT EXISTS ix_mv_customer_feature_store_sales ON feature_layer.mv_customer_feature_store_legacy(feat_gross_sales, feat_margin_amount);
CREATE INDEX IF NOT EXISTS ix_mv_customer_feature_store_activity ON feature_layer.mv_customer_feature_store_legacy(feat_last_any_activity_ts);

CREATE TABLE IF NOT EXISTS feature_layer.z_customer_model_input_snapshot_legacy (
    snapshot_id UUID DEFAULT gen_random_uuid(),
    snapshot_date DATE NOT NULL,
    customer_id BIGINT NOT NULL,
    feature_payload JSONB NOT NULL,
    label_customer_risk INTEGER,
    created_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (snapshot_date, customer_id)
);
CREATE INDEX IF NOT EXISTS ix_snapshot_customer_date ON feature_layer.z_customer_model_input_snapshot_legacy(customer_id, snapshot_date);
CREATE INDEX IF NOT EXISTS ix_snapshot_payload_gin ON feature_layer.z_customer_model_input_snapshot_legacy USING GIN(feature_payload);

CREATE OR REPLACE FUNCTION feature_layer.fn_insert_customer_model_snapshot_legacy(p_snapshot_date DATE)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE v_count BIGINT;
BEGIN
    INSERT INTO audit_layer.z_batch_run_log_legacy(job_name, run_status, message) VALUES ('fn_insert_customer_model_snapshot_legacy', 'STARTED', 'snapshot=' || p_snapshot_date);
    DELETE FROM feature_layer.z_customer_model_input_snapshot_legacy WHERE snapshot_date = p_snapshot_date;
    INSERT INTO feature_layer.z_customer_model_input_snapshot_legacy (snapshot_date, customer_id, feature_payload, label_customer_risk)
    SELECT p_snapshot_date, customer_id, to_jsonb(fs) - 'customer_name_clean' - 'email_clean',
           CASE WHEN feat_bad_payment_flag = 1 OR feat_high_return_flag = 1 OR feat_support_pressure_flag = 1 OR feat_note_fraud_flag = 1 THEN 1 ELSE 0 END
    FROM feature_layer.mv_customer_feature_store_legacy fs;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    INSERT INTO audit_layer.z_batch_run_log_legacy(job_name, run_status, rows_processed, message) VALUES ('fn_insert_customer_model_snapshot_legacy', 'FINISHED', v_count, 'snapshot=' || p_snapshot_date);
    RETURN v_count;
END;
$$;

-- ============================================================================
-- 06. ONE GIANT LEGACY REPORT FUNCTION
-- ============================================================================
CREATE OR REPLACE FUNCTION report_layer.fn_extremely_confusing_customer_report_legacy(p_from_date DATE, p_to_date DATE, p_region VARCHAR DEFAULT NULL, p_debug_mode INTEGER DEFAULT 0)
RETURNS TABLE (report_customer_id BIGINT, report_customer_code VARCHAR, report_customer_name TEXT, report_region TEXT, report_class TEXT, report_total_orders BIGINT, report_good_orders BIGINT, report_bad_orders BIGINT, report_gross_sales NUMERIC, report_margin_amount NUMERIC, report_payment_success_pct NUMERIC, report_return_cnt BIGINT, report_support_open_cnt BIGINT, report_marketing_touch_cnt BIGINT, report_last_activity_ts TIMESTAMP, report_legacy_score NUMERIC, report_legacy_bucket TEXT, report_reason_blob TEXT)
LANGUAGE SQL
AS $$
WITH
date_guard AS (SELECT COALESCE(p_from_date, DATE '1900-01-01') AS safe_from_date, COALESCE(p_to_date, CURRENT_DATE) AS safe_to_date, p_region AS safe_region, p_debug_mode AS safe_debug),
f0 AS (SELECT fs.* FROM feature_layer.mv_customer_feature_store_legacy fs CROSS JOIN date_guard dg WHERE dg.safe_region IS NULL OR UPPER(fs.region_clean) = UPPER(dg.safe_region)),
recent_order_noise AS (SELECT h.oh_customer_id, COUNT(*) AS recent_order_rows, MAX(h.oh_order_ts) AS recent_order_ts FROM raw_layer.z_sales_order_header_legacy h CROSS JOIN date_guard dg WHERE h.oh_order_ts >= dg.safe_from_date AND h.oh_order_ts < dg.safe_to_date + INTERVAL '1 day' GROUP BY h.oh_customer_id),
recent_support_noise AS (SELECT s.s_customer_id, COUNT(*) AS recent_support_rows, SUM(CASE WHEN s.s_priority IN ('HIGH', 'URGENT', 'CRITICAL') THEN 1 ELSE 0 END) AS recent_hot_support_rows FROM raw_layer.z_support_case_legacy s CROSS JOIN date_guard dg WHERE s.s_created_ts >= dg.safe_from_date AND s.s_created_ts < dg.safe_to_date + INTERVAL '1 day' GROUP BY s.s_customer_id),
combined AS (SELECT f0.*, COALESCE(ro.recent_order_rows,0) AS recent_order_rows, COALESCE(rs.recent_support_rows,0) AS recent_support_rows, COALESCE(rs.recent_hot_support_rows,0) AS recent_hot_support_rows FROM f0 LEFT JOIN recent_order_noise ro ON ro.oh_customer_id = f0.customer_id LEFT JOIN recent_support_noise rs ON rs.s_customer_id = f0.customer_id),
score_layer AS (SELECT combined.*, (
     CASE WHEN feat_no_order_flag = 1 THEN 25 ELSE 0 END
    + CASE WHEN feat_bad_payment_flag = 1 THEN 20 ELSE 0 END
    + CASE WHEN feat_high_return_flag = 1 THEN 18 ELSE 0 END
    + CASE WHEN feat_support_pressure_flag = 1 THEN 15 ELSE 0 END
    + CASE WHEN feat_marketing_negative_flag = 1 THEN 8 ELSE 0 END
    + CASE WHEN feat_note_fraud_flag = 1 THEN 30 ELSE 0 END
    + CASE WHEN feat_margin_ratio < 0.05 AND feat_total_orders > 0 THEN 10 ELSE 0 END
    + CASE WHEN feat_return_rate > 0.30 THEN 12 ELSE 0 END
    + CASE WHEN feat_support_per_order > 1 THEN 9 ELSE 0 END
    + CASE WHEN recent_hot_support_rows >= 3 THEN 10 ELSE 0 END
    + CASE WHEN feat_gross_sales >= 20000 THEN -15 ELSE 0 END
    + CASE WHEN feat_margin_amount >= 5000 THEN -10 ELSE 0 END
    + CASE WHEN ohe_class_vip = 1 THEN -10 ELSE 0 END
    + CASE WHEN ohe_class_gold = 1 THEN -5 ELSE 0 END
    + CASE WHEN feat_marketing_positive_ratio >= 0.5 THEN -3 ELSE 0 END
)::NUMERIC AS legacy_score_calc FROM combined),
bucket_layer AS (SELECT score_layer.*, CASE WHEN legacy_score_calc >= 80 THEN 'EXTREME_REVIEW' WHEN legacy_score_calc >= 55 THEN 'HIGH_RISK_REVIEW' WHEN legacy_score_calc >= 30 THEN 'MEDIUM_RISK_WATCH' WHEN legacy_score_calc <= -10 THEN 'HIGH_VALUE_KEEP' ELSE 'NORMAL_KEEP_MONITORING' END AS legacy_bucket_calc FROM score_layer)
SELECT customer_id, customer_code, customer_name_clean::TEXT, region_clean::TEXT, class_clean::TEXT, feat_total_orders::BIGINT, feat_good_orders::BIGINT, feat_bad_orders::BIGINT, feat_gross_sales, feat_margin_amount, feat_payment_success_pct, feat_real_return_cnt::BIGINT, feat_support_open_cnt::BIGINT, feat_marketing_touch_cnt::BIGINT, NULLIF(feat_last_any_activity_ts, TIMESTAMP '1900-01-01'), legacy_score_calc, legacy_bucket_calc,
CONCAT('orders=', feat_total_orders, '|good=', feat_good_orders, '|bad=', feat_bad_orders, '|pay_pct=', feat_payment_success_pct, '|returns=', feat_real_return_cnt, '|support_open=', feat_support_open_cnt, '|mkt_neg=', feat_marketing_negative_cnt, '|fraud_note=', feat_note_fraud_word_cnt, '|score=', legacy_score_calc, '|debug=', p_debug_mode)
FROM bucket_layer
WHERE feat_total_orders > 0 OR feat_support_open_cnt > 0 OR feat_marketing_touch_cnt > 0 OR p_debug_mode = 1
ORDER BY legacy_score_calc DESC, feat_gross_sales DESC, feat_total_orders DESC, customer_name_clean ASC;
$$;

-- ============================================================================
-- 07. DATA QUALITY CHECKS
-- ============================================================================
-- dq_customer_null_code
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_customer_master_legacy WHERE c_code IS NULL;

-- dq_customer_duplicate_email
SELECT email_clean, COUNT(*) AS cnt FROM stage_layer.v_customer_clean_legacy GROUP BY email_clean HAVING COUNT(*) > 1;

-- dq_order_missing_customer
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_sales_order_header_legacy h LEFT JOIN raw_layer.z_customer_master_legacy c ON h.oh_customer_id = c.c_id WHERE c.c_id IS NULL;

-- dq_line_missing_product
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_sales_order_line_legacy l LEFT JOIN raw_layer.z_product_dictionary_legacy p ON l.ol_product_id = p.p_id WHERE p.p_id IS NULL;

-- dq_payment_without_order
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_payment_attempt_legacy p LEFT JOIN raw_layer.z_sales_order_header_legacy h ON p.pay_order_id = h.oh_id WHERE h.oh_id IS NULL;

-- dq_return_without_order
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_return_case_legacy r LEFT JOIN raw_layer.z_sales_order_header_legacy h ON r.r_order_id = h.oh_id WHERE h.oh_id IS NULL;

-- dq_support_without_customer
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_support_case_legacy s LEFT JOIN raw_layer.z_customer_master_legacy c ON s.s_customer_id = c.c_id WHERE c.c_id IS NULL;

-- dq_marketing_without_customer
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_marketing_touch_legacy m LEFT JOIN raw_layer.z_customer_master_legacy c ON m.m_customer_id = c.c_id WHERE c.c_id IS NULL;

-- dq_negative_qty
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_sales_order_line_legacy WHERE ol_qty < 0;

-- dq_negative_price
SELECT COUNT(*) AS bad_rows FROM raw_layer.z_sales_order_line_legacy WHERE ol_unit_price < 0;

-- ============================================================================
-- 08. ANALYZE COMMANDS
-- ============================================================================
ANALYZE raw_layer.z_customer_master_legacy;
ANALYZE raw_layer.z_customer_class_history_legacy;
ANALYZE raw_layer.z_product_dictionary_legacy;
ANALYZE raw_layer.z_sales_order_header_legacy;
ANALYZE raw_layer.z_sales_order_line_legacy;
ANALYZE raw_layer.z_payment_attempt_legacy;
ANALYZE raw_layer.z_return_case_legacy;
ANALYZE raw_layer.z_support_case_legacy;
ANALYZE raw_layer.z_marketing_touch_legacy;
ANALYZE raw_layer.z_customer_note_legacy;
ANALYZE audit_layer.z_batch_run_log_legacy;
ANALYZE feature_layer.mv_customer_feature_store_legacy;

-- ============================================================================
-- 09. MODEL FEATURE SELECTION VIEW
-- ============================================================================
CREATE OR REPLACE VIEW feature_layer.v_customer_model_matrix_legacy AS
SELECT
    customer_id,
    feat_account_new_30d,
    feat_account_mid_31_180d,
    feat_account_old_180d_plus,
    feat_total_orders,
    feat_good_orders,
    feat_bad_orders,
    feat_total_units,
    feat_gross_sales,
    feat_cost_amount,
    feat_margin_amount,
    feat_avg_line_amount,
    feat_payment_attempt_cnt,
    feat_payment_success_cnt,
    feat_payment_failed_cnt,
    feat_payment_success_pct,
    feat_return_cnt,
    feat_real_return_cnt,
    feat_refund_amount,
    feat_support_cnt,
    feat_support_open_cnt,
    feat_support_high_cnt,
    feat_marketing_touch_cnt,
    feat_marketing_positive_cnt,
    feat_marketing_negative_cnt,
    feat_note_cnt,
    feat_note_fraud_word_cnt,
    feat_note_angry_word_cnt,
    feat_note_vip_word_cnt,
    feat_no_order_flag,
    feat_bad_payment_flag,
    feat_high_return_flag,
    feat_support_pressure_flag,
    feat_marketing_negative_flag,
    feat_note_fraud_flag,
    feat_avg_order_value,
    feat_margin_ratio,
    feat_return_rate,
    feat_support_per_order,
    feat_marketing_positive_ratio,
    ohe_region_apac,
    ohe_region_emea,
    ohe_region_amer,
    ohe_region_asean,
    ohe_region_malaysia,
    ohe_region_singapore,
    ohe_region_thailand,
    ohe_region_china,
    ohe_region_india,
    ohe_region_japan,
    ohe_region_korea,
    ohe_region_europe,
    ohe_region_unknown_region,
    ohe_country_malaysia,
    ohe_country_singapore,
    ohe_country_thailand,
    ohe_country_china,
    ohe_country_india,
    ohe_country_japan,
    ohe_country_korea,
    ohe_country_usa,
    ohe_country_germany,
    ohe_country_unknown_country,
    ohe_gender_male,
    ohe_gender_female,
    ohe_gender_unknown_gender,
    ohe_age_18_25,
    ohe_age_26_35,
    ohe_age_36_45,
    ohe_age_46_55,
    ohe_age_56_plus,
    ohe_age_unknown_age,
    ohe_class_vip,
    ohe_class_gold,
    ohe_class_silver,
    ohe_class_bronze,
    ohe_class_risk,
    ohe_class_no_class
FROM feature_layer.mv_customer_feature_store_legacy;

-- ============================================================================
-- 10. CHANNEL AND STATUS PIVOT-LIKE LEGACY VIEW
-- ============================================================================
CREATE OR REPLACE VIEW feature_layer.v_customer_pivot_noise_legacy AS
SELECT
    h.oh_customer_id AS customer_id,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'COMPLETED' THEN 1 ELSE 0 END) AS pv_order_status_completed,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'SHIPPED' THEN 1 ELSE 0 END) AS pv_order_status_shipped,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'DELIVERED' THEN 1 ELSE 0 END) AS pv_order_status_delivered,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'CANCELLED' THEN 1 ELSE 0 END) AS pv_order_status_cancelled,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'FAILED' THEN 1 ELSE 0 END) AS pv_order_status_failed,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'VOID' THEN 1 ELSE 0 END) AS pv_order_status_void,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'PENDING' THEN 1 ELSE 0 END) AS pv_order_status_pending,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'PROCESSING' THEN 1 ELSE 0 END) AS pv_order_status_processing,
    SUM(CASE WHEN COALESCE(h.oh_status, 'UNKNOWN_STATUS') = 'UNKNOWN_STATUS' THEN 1 ELSE 0 END) AS pv_order_status_unknown_status,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'DIRECT' THEN 1 ELSE 0 END) AS pv_channel_direct,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'STORE' THEN 1 ELSE 0 END) AS pv_channel_store,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'AFFILIATE' THEN 1 ELSE 0 END) AS pv_channel_affiliate,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'MARKETPLACE' THEN 1 ELSE 0 END) AS pv_channel_marketplace,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'EMAIL' THEN 1 ELSE 0 END) AS pv_channel_email,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'PUSH' THEN 1 ELSE 0 END) AS pv_channel_push,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'PARTNER' THEN 1 ELSE 0 END) AS pv_channel_partner,
    SUM(CASE WHEN COALESCE(h.oh_source_channel, 'UNKNOWN_CHANNEL') = 'UNKNOWN_CHANNEL' THEN 1 ELSE 0 END) AS pv_channel_unknown_channel,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'PREMIUM' THEN 1 ELSE 0 END) AS pv_family_premium,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'ENTERPRISE' THEN 1 ELSE 0 END) AS pv_family_enterprise,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'BASIC' THEN 1 ELSE 0 END) AS pv_family_basic,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'ACCESSORY' THEN 1 ELSE 0 END) AS pv_family_accessory,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'SERVICE' THEN 1 ELSE 0 END) AS pv_family_service,
    SUM(CASE WHEN COALESCE(p.p_family, 'UNKNOWN_FAMILY') = 'UNKNOWN_FAMILY' THEN 1 ELSE 0 END) AS pv_family_unknown_family
FROM raw_layer.z_sales_order_header_legacy h
LEFT JOIN raw_layer.z_sales_order_line_legacy l ON h.oh_id = l.ol_order_id
LEFT JOIN raw_layer.z_product_dictionary_legacy p ON l.ol_product_id = p.p_id
GROUP BY h.oh_customer_id;

-- ============================================================================
-- 11. REFRESH PROCEDURE
-- ============================================================================
CREATE OR REPLACE PROCEDURE feature_layer.sp_refresh_legacy_customer_features(p_snapshot_date DATE)
LANGUAGE plpgsql
AS $$
DECLARE v_rows BIGINT;
BEGIN
    INSERT INTO audit_layer.z_batch_run_log_legacy(job_name, run_status, message) VALUES ('sp_refresh_legacy_customer_features', 'STARTED', 'start refresh');
    REFRESH MATERIALIZED VIEW feature_layer.mv_customer_feature_store_legacy;
    SELECT feature_layer.fn_insert_customer_model_snapshot_legacy(p_snapshot_date) INTO v_rows;
    INSERT INTO audit_layer.z_batch_run_log_legacy(job_name, run_status, rows_processed, message) VALUES ('sp_refresh_legacy_customer_features', 'FINISHED', v_rows, 'finished refresh');
EXCEPTION WHEN OTHERS THEN
    INSERT INTO audit_layer.z_batch_run_log_legacy(job_name, run_status, message) VALUES ('sp_refresh_legacy_customer_features', 'FAILED', SQLERRM);
    RAISE;
END;
$$;

-- ============================================================================
-- 12. EXTRA LEGACY WRAPPER VIEWS
-- ============================================================================
CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_01_do_not_delete AS
SELECT
    1 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (1 = 1);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_02_do_not_delete AS
SELECT
    2 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (2 = 2);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_03_do_not_delete AS
SELECT
    3 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (3 = 3);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_04_do_not_delete AS
SELECT
    4 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (4 = 4);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_05_do_not_delete AS
SELECT
    5 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (5 = 5);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_06_do_not_delete AS
SELECT
    6 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (6 = 6);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_07_do_not_delete AS
SELECT
    7 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (7 = 7);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_08_do_not_delete AS
SELECT
    8 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (8 = 8);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_09_do_not_delete AS
SELECT
    9 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (9 = 9);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_10_do_not_delete AS
SELECT
    10 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (10 = 10);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_11_do_not_delete AS
SELECT
    11 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (11 = 11);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_12_do_not_delete AS
SELECT
    12 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (12 = 12);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_13_do_not_delete AS
SELECT
    13 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (13 = 13);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_14_do_not_delete AS
SELECT
    14 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (14 = 14);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_15_do_not_delete AS
SELECT
    15 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (15 = 15);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_16_do_not_delete AS
SELECT
    16 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (16 = 16);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_17_do_not_delete AS
SELECT
    17 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (17 = 17);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_18_do_not_delete AS
SELECT
    18 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (18 = 18);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_19_do_not_delete AS
SELECT
    19 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (19 = 19);

CREATE OR REPLACE VIEW report_layer.v_legacy_wrapper_20_do_not_delete AS
SELECT
    20 AS wrapper_id,
    customer_id
    customer_code
    region_clean
    class_clean
    feat_total_orders
    feat_gross_sales
    feat_margin_amount
    feat_payment_success_pct
    feat_return_rate
    feat_support_per_order
    feat_marketing_positive_ratio,
    CASE
        WHEN feat_bad_payment_flag = 1 THEN 'PAYMENT_ISSUE'
        WHEN feat_high_return_flag = 1 THEN 'RETURN_ISSUE'
        WHEN feat_support_pressure_flag = 1 THEN 'SUPPORT_ISSUE'
        ELSE 'NO_MAJOR_ISSUE'
    END AS wrapper_status
FROM feature_layer.mv_customer_feature_store_legacy
WHERE (20 = 20);

-- ============================================================================
-- 13. EXAMPLE USAGE
-- ============================================================================
-- CALL feature_layer.sp_refresh_legacy_customer_features(CURRENT_DATE);
-- SELECT * FROM report_layer.fn_extremely_confusing_customer_report_legacy(DATE '2025-01-01', DATE '2025-12-31', NULL, 0);
-- SELECT * FROM feature_layer.v_customer_model_matrix_legacy LIMIT 100;

-- END OF FILE
