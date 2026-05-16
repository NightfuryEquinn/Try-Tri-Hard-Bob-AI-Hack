/*
================================================================================
 EXTREMELY CONFUSING LEGACY SQL DEMO
 Dialect: PostgreSQL

 Purpose:
   This SQL is intentionally written in a confusing legacy style for testing,
   code review practice, and refactoring exercises.

 Warning:
   This is NOT recommended production style.
   The query mixes business rules, reporting logic, scoring logic,
   audit logic, customer segmentation, payment validation, return behavior,
   and marketing engagement in one oversized function.
================================================================================
*/


/* ============================================================================
   SECTION 1: TABLES
   These CREATE TABLE statements are included so tools can detect table names.
============================================================================ */

CREATE TABLE IF NOT EXISTS z_customer_master_legacy (
    c_id BIGINT PRIMARY KEY,
    c_code VARCHAR(40),
    c_full_name VARCHAR(255),
    c_email VARCHAR(255),
    c_region VARCHAR(80),
    c_country VARCHAR(80),
    c_created_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    c_deleted_flag CHAR(1) NOT NULL DEFAULT 'N'
);

CREATE TABLE IF NOT EXISTS z_customer_class_history_legacy (
    h_id BIGINT PRIMARY KEY,
    h_customer_id BIGINT NOT NULL,
    h_class_code VARCHAR(50),
    h_class_label VARCHAR(100),
    h_valid_from DATE NOT NULL,
    h_valid_to DATE,
    h_is_manual_override CHAR(1) DEFAULT 'N',
    FOREIGN KEY (h_customer_id) REFERENCES z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS z_product_dictionary_legacy (
    p_id BIGINT PRIMARY KEY,
    p_sku VARCHAR(80),
    p_name VARCHAR(255),
    p_family VARCHAR(100),
    p_cost NUMERIC(14, 4),
    p_list_price NUMERIC(14, 4),
    p_enabled_flag CHAR(1) DEFAULT 'Y'
);

CREATE TABLE IF NOT EXISTS z_sales_order_header_legacy (
    oh_id BIGINT PRIMARY KEY,
    oh_customer_id BIGINT NOT NULL,
    oh_order_no VARCHAR(80),
    oh_order_ts TIMESTAMP NOT NULL,
    oh_status VARCHAR(40),
    oh_discount_total NUMERIC(14, 4) DEFAULT 0,
    oh_shipping_total NUMERIC(14, 4) DEFAULT 0,
    oh_tax_total NUMERIC(14, 4) DEFAULT 0,
    oh_source_channel VARCHAR(80),
    FOREIGN KEY (oh_customer_id) REFERENCES z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS z_sales_order_line_legacy (
    ol_id BIGINT PRIMARY KEY,
    ol_order_id BIGINT NOT NULL,
    ol_product_id BIGINT NOT NULL,
    ol_qty NUMERIC(14, 4),
    ol_unit_price NUMERIC(14, 4),
    ol_line_status VARCHAR(40),
    FOREIGN KEY (ol_order_id) REFERENCES z_sales_order_header_legacy(oh_id),
    FOREIGN KEY (ol_product_id) REFERENCES z_product_dictionary_legacy(p_id)
);

CREATE TABLE IF NOT EXISTS z_payment_attempt_legacy (
    pay_id BIGINT PRIMARY KEY,
    pay_order_id BIGINT NOT NULL,
    pay_status VARCHAR(40),
    pay_method VARCHAR(80),
    pay_amount NUMERIC(14, 4),
    pay_created_ts TIMESTAMP,
    pay_captured_ts TIMESTAMP,
    pay_gateway_ref VARCHAR(255),
    FOREIGN KEY (pay_order_id) REFERENCES z_sales_order_header_legacy(oh_id)
);

CREATE TABLE IF NOT EXISTS z_return_case_legacy (
    r_id BIGINT PRIMARY KEY,
    r_order_id BIGINT NOT NULL,
    r_status VARCHAR(40),
    r_reason_code VARCHAR(80),
    r_created_ts TIMESTAMP NOT NULL,
    r_closed_ts TIMESTAMP,
    r_refund_amount NUMERIC(14, 4),
    FOREIGN KEY (r_order_id) REFERENCES z_sales_order_header_legacy(oh_id)
);

CREATE TABLE IF NOT EXISTS z_support_case_legacy (
    s_id BIGINT PRIMARY KEY,
    s_customer_id BIGINT NOT NULL,
    s_status VARCHAR(40),
    s_priority VARCHAR(40),
    s_topic VARCHAR(120),
    s_created_ts TIMESTAMP NOT NULL,
    s_closed_ts TIMESTAMP,
    FOREIGN KEY (s_customer_id) REFERENCES z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS z_marketing_touch_legacy (
    m_id BIGINT PRIMARY KEY,
    m_customer_id BIGINT NOT NULL,
    m_touch_type VARCHAR(80),
    m_campaign_code VARCHAR(120),
    m_touch_ts TIMESTAMP NOT NULL,
    m_cost NUMERIC(14, 4),
    FOREIGN KEY (m_customer_id) REFERENCES z_customer_master_legacy(c_id)
);

CREATE TABLE IF NOT EXISTS z_customer_note_legacy (
    n_id BIGINT PRIMARY KEY,
    n_customer_id BIGINT NOT NULL,
    n_note_type VARCHAR(80),
    n_note_text TEXT,
    n_created_ts TIMESTAMP NOT NULL,
    FOREIGN KEY (n_customer_id) REFERENCES z_customer_master_legacy(c_id)
);


/* ============================================================================
   SECTION 2: ONE GIANT LEGACY FUNCTION
============================================================================ */

CREATE OR REPLACE FUNCTION fn_legacy_everything_customer_report_do_not_touch(
    in_from_date DATE,
    in_to_date DATE,
    in_region VARCHAR DEFAULT NULL,
    in_debug_mode INTEGER DEFAULT 0
)
RETURNS TABLE (
    report_customer_id BIGINT,
    report_customer_code VARCHAR,
    report_customer_name VARCHAR,
    report_region VARCHAR,
    report_current_class VARCHAR,
    report_status_bucket TEXT,
    report_orders BIGINT,
    report_good_orders BIGINT,
    report_bad_orders BIGINT,
    report_units NUMERIC,
    report_raw_sales NUMERIC,
    report_net_sales NUMERIC,
    report_margin_guess NUMERIC,
    report_payment_success_pct NUMERIC,
    report_return_cases BIGINT,
    report_open_support_cases BIGINT,
    report_marketing_touches BIGINT,
    report_customer_age_days NUMERIC,
    report_last_activity_ts TIMESTAMP,
    report_legacy_score NUMERIC,
    report_reason_blob TEXT
)
LANGUAGE SQL
AS $$
WITH RECURSIVE
-- Confusing date spine. Not needed for the final report, but legacy code kept it.
q0_date_noise AS (
    SELECT in_from_date::DATE AS d, 1 AS hop
    UNION ALL
    SELECT (d + INTERVAL '1 day')::DATE, hop + 1
    FROM q0_date_noise
    WHERE d < in_to_date::DATE
      AND hop < 370
),

-- Base customers, but using old naming and strange filters.
q1_cust AS (
    SELECT
        aa.c_id AS x1,
        aa.c_code AS x2,
        COALESCE(NULLIF(TRIM(aa.c_full_name), ''), 'UNKNOWN CUSTOMER') AS x3,
        LOWER(COALESCE(aa.c_email, 'missing-email')) AS x4,
        aa.c_region AS x5,
        aa.c_country AS x6,
        aa.c_created_on AS x7,
        CASE
            WHEN aa.c_deleted_flag = 'Y' THEN 1
            WHEN aa.c_deleted_flag = 'N' THEN 0
            ELSE 99
        END AS x8,
        CASE
            WHEN aa.c_created_on IS NULL THEN 999999
            ELSE EXTRACT(DAY FROM CURRENT_TIMESTAMP - aa.c_created_on)
        END AS x9
    FROM z_customer_master_legacy aa
    WHERE COALESCE(aa.c_deleted_flag, 'N') <> 'Y'
      AND (
            in_region IS NULL
            OR aa.c_region = in_region
            OR UPPER(aa.c_region) = UPPER(in_region)
          )
),

-- Current class, written in a needlessly nested way.
q2_class AS (
    SELECT
        keep_one.h_customer_id AS y1,
        COALESCE(keep_one.h_class_label, keep_one.h_class_code, 'NO_CLASS') AS y2,
        keep_one.h_is_manual_override AS y3
    FROM (
        SELECT
            z.*,
            ROW_NUMBER() OVER (
                PARTITION BY z.h_customer_id
                ORDER BY
                    CASE WHEN z.h_is_manual_override = 'Y' THEN 0 ELSE 1 END,
                    z.h_valid_from DESC,
                    z.h_id DESC
            ) AS rn_confusing
        FROM z_customer_class_history_legacy z
        WHERE z.h_valid_from <= CURRENT_DATE
          AND COALESCE(z.h_valid_to, DATE '2999-12-31') >= CURRENT_DATE
    ) keep_one
    WHERE keep_one.rn_confusing = 1
),

-- Sales line expansion.
q3_line_universe AS (
    SELECT
        h.oh_customer_id AS a_customer,
        h.oh_id AS a_order,
        h.oh_order_no AS a_order_no,
        h.oh_order_ts AS a_ts,
        h.oh_status AS a_status,
        h.oh_source_channel AS a_channel,
        COALESCE(h.oh_discount_total, 0) AS a_discount,
        COALESCE(h.oh_shipping_total, 0) AS a_shipping,
        COALESCE(h.oh_tax_total, 0) AS a_tax,
        l.ol_id AS b_line,
        l.ol_product_id AS b_product,
        COALESCE(l.ol_qty, 0) AS b_qty,
        COALESCE(l.ol_unit_price, 0) AS b_price,
        COALESCE(pd.p_cost, 0) AS b_cost,
        COALESCE(pd.p_family, 'NO_FAMILY') AS b_family,
        CASE
            WHEN h.oh_status IN ('COMPLETED', 'SHIPPED', 'DELIVERED') THEN 1
            WHEN h.oh_status IN ('CANCELLED', 'FAILED', 'VOID') THEN -1
            ELSE 0
        END AS status_math,
        CASE
            WHEN l.ol_line_status IN ('VOID', 'CANCELLED') THEN 0
            ELSE 1
        END AS line_alive_flag
    FROM z_sales_order_header_legacy h
    LEFT JOIN z_sales_order_line_legacy l
        ON h.oh_id = l.ol_order_id
    LEFT JOIN z_product_dictionary_legacy pd
        ON l.ol_product_id = pd.p_id
    WHERE h.oh_order_ts >= in_from_date
      AND h.oh_order_ts < (in_to_date + INTERVAL '1 day')
      AND COALESCE(h.oh_status, '???') NOT IN ('DRAFT', 'TEST', 'SANDBOX')
),

-- Order aggregation with weird math.
q4_order_folded AS (
    SELECT
        a_customer AS k_customer,
        a_order AS k_order,
        MAX(a_ts) AS order_ts,
        MAX(a_status) AS order_status,
        MAX(a_channel) AS order_channel,
        SUM(
            CASE
                WHEN line_alive_flag = 0 THEN 0
                WHEN b_qty < 0 THEN 0
                ELSE b_qty
            END
        ) AS units_x,
        SUM(
            CASE
                WHEN line_alive_flag = 0 THEN 0
                ELSE b_qty * b_price
            END
        ) AS gross_x,
        MAX(a_discount) AS discount_x,
        MAX(a_shipping) AS shipping_x,
        MAX(a_tax) AS tax_x,
        SUM(
            CASE
                WHEN line_alive_flag = 0 THEN 0
                ELSE b_qty * b_cost
            END
        ) AS cost_x,
        SUM(
            CASE
                WHEN b_family IN ('PREMIUM', 'ENTERPRISE') THEN 1
                ELSE 0
            END
        ) AS premium_line_count_x,
        MAX(status_math) AS status_math_x
    FROM q3_line_universe
    GROUP BY a_customer, a_order
),

-- Sales metrics.
q5_sales AS (
    SELECT
        k_customer AS s_customer,
        COUNT(DISTINCT k_order) AS s_orders,
        COUNT(DISTINCT CASE WHEN status_math_x = 1 THEN k_order END) AS s_good_orders,
        COUNT(DISTINCT CASE WHEN status_math_x = -1 THEN k_order END) AS s_bad_orders,
        SUM(units_x) AS s_units,
        ROUND(SUM(gross_x), 2) AS s_raw_sales,
        ROUND(SUM(gross_x - discount_x + shipping_x + tax_x), 2) AS s_net_sales,
        ROUND(SUM(gross_x - discount_x - cost_x), 2) AS s_margin_guess,
        SUM(premium_line_count_x) AS s_premium_lines,
        MAX(order_ts) AS s_last_order_ts,
        SUM(
            CASE
                WHEN order_channel IN ('AFFILIATE', 'MARKETPLACE') THEN 2
                WHEN order_channel IN ('DIRECT', 'STORE') THEN 1
                ELSE 0
            END
        ) AS s_channel_weight
    FROM q4_order_folded
    GROUP BY k_customer
),

-- Payment chaos.
q6_payment_ranked AS (
    SELECT
        oh.oh_customer_id AS p_customer,
        pa.pay_order_id AS p_order,
        pa.pay_status AS p_status,
        pa.pay_method AS p_method,
        pa.pay_amount AS p_amount,
        COALESCE(pa.pay_captured_ts, pa.pay_created_ts) AS p_ts,
        ROW_NUMBER() OVER (
            PARTITION BY pa.pay_order_id
            ORDER BY
                CASE
                    WHEN pa.pay_status IN ('SUCCESS', 'CAPTURED', 'SETTLED') THEN 0
                    WHEN pa.pay_status IN ('PENDING', 'PROCESSING') THEN 1
                    ELSE 2
                END,
                COALESCE(pa.pay_captured_ts, pa.pay_created_ts) DESC,
                pa.pay_id DESC
        ) AS p_rank_magic
    FROM z_payment_attempt_legacy pa
    INNER JOIN z_sales_order_header_legacy oh
        ON pa.pay_order_id = oh.oh_id
    WHERE COALESCE(pa.pay_captured_ts, pa.pay_created_ts) >= in_from_date
      AND COALESCE(pa.pay_captured_ts, pa.pay_created_ts) < (in_to_date + INTERVAL '1 day')
),

q7_payment AS (
    SELECT
        p_customer,
        COUNT(*) AS pay_all_attempts,
        SUM(CASE WHEN p_status IN ('SUCCESS', 'CAPTURED', 'SETTLED') THEN 1 ELSE 0 END) AS pay_success_attempts,
        SUM(CASE WHEN p_status IN ('FAILED', 'DECLINED', 'REVERSED') THEN 1 ELSE 0 END) AS pay_fail_attempts,
        MAX(p_ts) AS pay_last_ts,
        ROUND(
            CASE
                WHEN COUNT(*) = 0 THEN 0
                ELSE SUM(CASE WHEN p_status IN ('SUCCESS', 'CAPTURED', 'SETTLED') THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
            END,
            2
        ) AS pay_success_pct
    FROM q6_payment_ranked
    WHERE p_rank_magic = 1
       OR p_status IN ('FAILED', 'DECLINED', 'REVERSED')
    GROUP BY p_customer
),

-- Returns.
q8_returns AS (
    SELECT
        oh.oh_customer_id AS r_customer,
        COUNT(DISTINCT rc.r_id) AS r_cases,
        COUNT(DISTINCT CASE WHEN rc.r_status IN ('APPROVED', 'REFUNDED', 'PARTIAL_REFUND') THEN rc.r_id END) AS r_real_cases,
        ROUND(SUM(COALESCE(rc.r_refund_amount, 0)), 2) AS r_refund_total,
        MAX(COALESCE(rc.r_closed_ts, rc.r_created_ts)) AS r_last_ts
    FROM z_return_case_legacy rc
    INNER JOIN z_sales_order_header_legacy oh
        ON rc.r_order_id = oh.oh_id
    WHERE rc.r_created_ts >= in_from_date
      AND rc.r_created_ts < (in_to_date + INTERVAL '1 day')
    GROUP BY oh.oh_customer_id
),

-- Support.
q9_support AS (
    SELECT
        s_customer_id AS t_customer,
        COUNT(*) AS t_cases,
        SUM(CASE WHEN s_status NOT IN ('CLOSED', 'RESOLVED') THEN 1 ELSE 0 END) AS t_open_cases,
        SUM(CASE WHEN s_priority IN ('HIGH', 'URGENT', 'CRITICAL') THEN 1 ELSE 0 END) AS t_hot_cases,
        MAX(COALESCE(s_closed_ts, s_created_ts)) AS t_last_ts,
        STRING_AGG(DISTINCT COALESCE(s_topic, 'NO_TOPIC'), ',' ORDER BY COALESCE(s_topic, 'NO_TOPIC')) AS t_topic_blob
    FROM z_support_case_legacy
    WHERE s_created_ts >= in_from_date
      AND s_created_ts < (in_to_date + INTERVAL '1 day')
    GROUP BY s_customer_id
),

-- Marketing.
q10_marketing AS (
    SELECT
        m_customer_id AS m_customer,
        COUNT(*) AS m_touches,
        SUM(CASE WHEN m_touch_type IN ('EMAIL_CLICK', 'AD_CLICK', 'PUSH_CLICK') THEN 1 ELSE 0 END) AS m_click_like,
        SUM(CASE WHEN m_touch_type IN ('UNSUBSCRIBE', 'SPAM_REPORT') THEN 1 ELSE 0 END) AS m_negative_like,
        ROUND(SUM(COALESCE(m_cost, 0)), 2) AS m_cost_guess,
        MAX(m_touch_ts) AS m_last_ts
    FROM z_marketing_touch_legacy
    WHERE m_touch_ts >= in_from_date
      AND m_touch_ts < (in_to_date + INTERVAL '1 day')
    GROUP BY m_customer_id
),

-- Notes. This is terrible because business logic reads free text.
q11_notes AS (
    SELECT
        n_customer_id AS n_customer,
        COUNT(*) AS n_count,
        SUM(
            CASE
                WHEN LOWER(COALESCE(n_note_text, '')) LIKE '%fraud%' THEN 5
                WHEN LOWER(COALESCE(n_note_text, '')) LIKE '%angry%' THEN 3
                WHEN LOWER(COALESCE(n_note_text, '')) LIKE '%vip%' THEN -2
                ELSE 0
            END
        ) AS n_bad_text_score,
        MAX(n_created_ts) AS n_last_ts
    FROM z_customer_note_legacy
    WHERE n_created_ts >= in_from_date
      AND n_created_ts < (in_to_date + INTERVAL '1 day')
    GROUP BY n_customer_id
),

-- Completely unnecessary lateral-style derived interpretation.
q12_big_mix AS (
    SELECT
        c.x1 AS zc_id,
        c.x2 AS zc_code,
        c.x3 AS zc_name,
        c.x5 AS zc_region,
        COALESCE(cls.y2, 'NO_CLASS') AS zc_class,
        COALESCE(s.s_orders, 0) AS zz_orders,
        COALESCE(s.s_good_orders, 0) AS zz_good_orders,
        COALESCE(s.s_bad_orders, 0) AS zz_bad_orders,
        COALESCE(s.s_units, 0) AS zz_units,
        COALESCE(s.s_raw_sales, 0) AS zz_raw_sales,
        COALESCE(s.s_net_sales, 0) AS zz_net_sales,
        COALESCE(s.s_margin_guess, 0) AS zz_margin_guess,
        COALESCE(p.pay_success_pct, 0) AS zz_payment_success_pct,
        COALESCE(r.r_real_cases, 0) AS zz_returns,
        COALESCE(t.t_open_cases, 0) AS zz_open_support,
        COALESCE(t.t_hot_cases, 0) AS zz_hot_support,
        COALESCE(m.m_touches, 0) AS zz_marketing,
        COALESCE(m.m_negative_like, 0) AS zz_marketing_negative,
        COALESCE(n.n_bad_text_score, 0) AS zz_note_score,
        c.x9 AS zz_age_days,
        GREATEST(
            COALESCE(s.s_last_order_ts, TIMESTAMP '1900-01-01'),
            COALESCE(p.pay_last_ts, TIMESTAMP '1900-01-01'),
            COALESCE(r.r_last_ts, TIMESTAMP '1900-01-01'),
            COALESCE(t.t_last_ts, TIMESTAMP '1900-01-01'),
            COALESCE(m.m_last_ts, TIMESTAMP '1900-01-01'),
            COALESCE(n.n_last_ts, TIMESTAMP '1900-01-01')
        ) AS zz_last_activity_ts,
        COALESCE(t.t_topic_blob, '') AS zz_topic_blob,
        COALESCE(s.s_channel_weight, 0) AS zz_channel_weight,
        COALESCE(s.s_premium_lines, 0) AS zz_premium_lines
    FROM q1_cust c
    LEFT JOIN q2_class cls ON cls.y1 = c.x1
    LEFT JOIN q5_sales s ON s.s_customer = c.x1
    LEFT JOIN q7_payment p ON p.p_customer = c.x1
    LEFT JOIN q8_returns r ON r.r_customer = c.x1
    LEFT JOIN q9_support t ON t.t_customer = c.x1
    LEFT JOIN q10_marketing m ON m.m_customer = c.x1
    LEFT JOIN q11_notes n ON n.n_customer = c.x1
),

-- Final scoring, but intentionally repeated and hard to follow.
q13_score AS (
    SELECT
        q.*,
        (
            CASE
                WHEN q.zz_orders = 0 THEN 30
                WHEN q.zz_good_orders = 0 AND q.zz_bad_orders > 0 THEN 40
                WHEN q.zz_good_orders >= 10 THEN -5
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_payment_success_pct = 0 AND q.zz_orders > 0 THEN 25
                WHEN q.zz_payment_success_pct < 60 THEN 20
                WHEN q.zz_payment_success_pct < 80 THEN 10
                WHEN q.zz_payment_success_pct >= 95 THEN -5
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_returns >= 10 THEN 25
                WHEN q.zz_returns >= 5 THEN 15
                WHEN q.zz_returns >= 2 THEN 8
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_open_support >= 10 THEN 20
                WHEN q.zz_open_support >= 5 THEN 12
                WHEN q.zz_open_support >= 1 THEN 4
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_hot_support >= 3 THEN 15
                WHEN q.zz_hot_support >= 1 THEN 7
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_last_activity_ts = TIMESTAMP '1900-01-01' THEN 18
                WHEN q.zz_last_activity_ts < CURRENT_TIMESTAMP - INTERVAL '365 days' THEN 16
                WHEN q.zz_last_activity_ts < CURRENT_TIMESTAMP - INTERVAL '180 days' THEN 10
                WHEN q.zz_last_activity_ts < CURRENT_TIMESTAMP - INTERVAL '90 days' THEN 5
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_marketing_negative >= 3 THEN 9
                WHEN q.zz_marketing_negative >= 1 THEN 4
                ELSE 0
            END
            +
            q.zz_note_score
            +
            CASE
                WHEN q.zz_net_sales >= 20000 AND q.zz_margin_guess > 5000 THEN -15
                WHEN q.zz_net_sales >= 10000 THEN -8
                WHEN q.zz_net_sales < 100 AND q.zz_orders > 0 THEN 6
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_premium_lines >= 5 THEN -4
                ELSE 0
            END
            +
            CASE
                WHEN q.zz_channel_weight >= 15 THEN 3
                ELSE 0
            END
        )::NUMERIC AS legacy_score
    FROM q12_big_mix q
),

-- More confusing label calculation.
q14_label AS (
    SELECT
        q13_score.*,
        CASE
            WHEN legacy_score >= 80 THEN 'RED_ZONE_REVIEW_NOW'
            WHEN legacy_score >= 55 THEN 'AMBER_ZONE_WATCH'
            WHEN legacy_score <= -10 THEN 'GREEN_ZONE_HIGH_VALUE'
            WHEN zz_orders = 0 THEN 'SLEEPING_OR_NEVER_BOUGHT'
            ELSE 'NORMAL_BUT_CHECK_CONTEXT'
        END AS weird_bucket,
        CONCAT(
            'orders=', zz_orders,
            '|good=', zz_good_orders,
            '|bad=', zz_bad_orders,
            '|pay=', zz_payment_success_pct,
            '|returns=', zz_returns,
            '|open_support=', zz_open_support,
            '|hot_support=', zz_hot_support,
            '|marketing=', zz_marketing,
            '|note_score=', zz_note_score,
            '|topics=', COALESCE(NULLIF(zz_topic_blob, ''), 'NA'),
            '|debug=', in_debug_mode
        ) AS reason_blob
    FROM q13_score
)

SELECT
    zc_id AS report_customer_id,
    zc_code AS report_customer_code,
    zc_name AS report_customer_name,
    zc_region AS report_region,
    zc_class AS report_current_class,
    weird_bucket AS report_status_bucket,
    zz_orders AS report_orders,
    zz_good_orders AS report_good_orders,
    zz_bad_orders AS report_bad_orders,
    zz_units AS report_units,
    zz_raw_sales AS report_raw_sales,
    zz_net_sales AS report_net_sales,
    zz_margin_guess AS report_margin_guess,
    zz_payment_success_pct AS report_payment_success_pct,
    zz_returns AS report_return_cases,
    zz_open_support AS report_open_support_cases,
    zz_marketing AS report_marketing_touches,
    zz_age_days AS report_customer_age_days,
    NULLIF(zz_last_activity_ts, TIMESTAMP '1900-01-01') AS report_last_activity_ts,
    legacy_score AS report_legacy_score,
    reason_blob AS report_reason_blob
FROM q14_label
WHERE
    (
        zz_orders > 0
        OR zz_open_support > 0
        OR zz_marketing > 0
        OR in_debug_mode = 1
    )
ORDER BY
    legacy_score DESC,
    zz_net_sales DESC,
    zz_orders DESC,
    zc_name ASC;
$$;


/* ============================================================================
   SECTION 3: EXAMPLE USAGE
============================================================================ */

-- SELECT *
-- FROM fn_legacy_everything_customer_report_do_not_touch(
--     DATE '2025-01-01',
--     DATE '2025-12-31',
--     NULL,
--     0
-- );

-- SELECT *
-- FROM fn_legacy_everything_customer_report_do_not_touch(
--     DATE '2025-01-01',
--     DATE '2025-12-31',
--     'Asia',
--     1
-- );
