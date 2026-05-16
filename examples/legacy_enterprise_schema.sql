-- Legacy Enterprise ERP System Schema
-- System: ACME_ERP_v3.2
-- Created: 2008
-- Last Modified: 2018
-- Database: Oracle 10g migrated to SQL Server 2012
-- Note: Contains multiple naming conventions from different development teams

-- ============================================
-- CUSTOMER MANAGEMENT MODULE
-- ============================================

-- Main customer table with Hungarian notation
CREATE TABLE tbl_CUST_MSTR_2008_FINAL_v3 (
    int_cust_id INT PRIMARY KEY,
    vch_f_name VARCHAR(50),
    vch_l_name VARCHAR(50),
    vch_mid_init VARCHAR(1),
    vch_email_addr VARCHAR(150),
    vch_phone_num VARCHAR(20),
    vch_mobile_ph VARCHAR(20),
    txt_addr_ln1 TEXT,
    txt_addr_ln2 TEXT,
    vch_city_nm VARCHAR(100),
    vch_state_cd VARCHAR(2),
    vch_zip_code VARCHAR(10),
    vch_country_cd VARCHAR(3),
    dt_birth_dt DATE,
    dt_reg_dt TIMESTAMP,
    dt_last_upd_dt TIMESTAMP,
    int_cust_type_id INT,
    int_cust_status_cd INT,
    dec_credit_lmt DECIMAL(12,2),
    bit_is_active BIT,
    bit_email_opt_in BIT,
    bit_sms_opt_in BIT,
    vch_tax_id_num VARCHAR(20),
    fk_sales_rep_id INT,
    fk_territory_id INT,
    int_loyalty_pts INT,
    vch_pref_lang VARCHAR(5),
    txt_notes TEXT
);

-- Customer address history table
CREATE TABLE TBL_CUST_ADDR_HIST_2010 (
    addr_hist_id INT PRIMARY KEY,
    fk_cust_id INT,
    vch_addr_type VARCHAR(20),
    txt_addr_ln1 TEXT,
    txt_addr_ln2 TEXT,
    vch_city_nm VARCHAR(100),
    vch_state_cd VARCHAR(2),
    vch_zip_code VARCHAR(10),
    dt_eff_from_dt DATE,
    dt_eff_to_dt DATE,
    dt_crt_dt TIMESTAMP,
    int_crt_by_usr_id INT
);

-- ============================================
-- PRODUCT CATALOG MODULE
-- ============================================

-- Product master table with mixed conventions
CREATE TABLE tbl_PRD_MSTR_CAT_v2 (
    prd_id INT PRIMARY KEY,
    vch_prd_code VARCHAR(50),
    vch_prd_name VARCHAR(200),
    txt_prd_desc TEXT,
    fk_cat_id INT,
    fk_subcat_id INT,
    fk_brand_id INT,
    fk_supplier_id INT,
    dec_unit_price DECIMAL(10,2),
    dec_cost_price DECIMAL(10,2),
    vch_uom VARCHAR(10),
    int_reorder_lvl INT,
    int_stock_qty INT,
    dec_weight_kg DECIMAL(8,3),
    dec_length_cm DECIMAL(8,2),
    dec_width_cm DECIMAL(8,2),
    dec_height_cm DECIMAL(8,2),
    bit_is_taxable BIT,
    bit_is_discountable BIT,
    bit_is_active BIT,
    dt_intro_dt DATE,
    dt_discontinue_dt DATE,
    dt_last_upd_dt TIMESTAMP,
    vch_sku VARCHAR(50),
    vch_barcode VARCHAR(50),
    int_warranty_months INT
);

-- Product category table
CREATE TABLE tbl_PRD_CAT_MSTR (
    cat_id INT PRIMARY KEY,
    vch_cat_name VARCHAR(100),
    vch_cat_code VARCHAR(20),
    txt_cat_desc TEXT,
    fk_parent_cat_id INT,
    int_display_order INT,
    bit_is_active BIT,
    dt_crt_dt TIMESTAMP
);

-- Product pricing history
CREATE TABLE TBL_PRD_PRICE_HIST_2015 (
    price_hist_id INT PRIMARY KEY,
    fk_prd_id INT,
    dec_old_price DECIMAL(10,2),
    dec_new_price DECIMAL(10,2),
    dt_eff_from_dt DATE,
    dt_eff_to_dt DATE,
    vch_reason_code VARCHAR(20),
    int_changed_by_usr_id INT,
    dt_change_dt TIMESTAMP
);

-- ============================================
-- ORDER MANAGEMENT MODULE
-- ============================================

-- Sales order header
CREATE TABLE tbl_ORD_HDR_MSTR_2012_v4 (
    ord_id INT PRIMARY KEY,
    vch_ord_num VARCHAR(50),
    fk_cust_id INT,
    fk_sales_rep_id INT,
    fk_ship_addr_id INT,
    fk_bill_addr_id INT,
    dt_ord_dt TIMESTAMP,
    dt_req_ship_dt DATE,
    dt_actual_ship_dt DATE,
    dt_delivery_dt DATE,
    int_ord_status_cd INT,
    dec_subtotal_amt DECIMAL(12,2),
    dec_tax_amt DECIMAL(12,2),
    dec_ship_amt DECIMAL(12,2),
    dec_discount_amt DECIMAL(12,2),
    dec_total_amt DECIMAL(12,2),
    vch_payment_method VARCHAR(20),
    vch_payment_ref VARCHAR(100),
    vch_ship_method VARCHAR(50),
    vch_tracking_num VARCHAR(100),
    txt_cust_notes TEXT,
    txt_internal_notes TEXT,
    dt_crt_dt TIMESTAMP,
    dt_last_upd_dt TIMESTAMP,
    int_crt_by_usr_id INT,
    int_upd_by_usr_id INT
);

-- Sales order line items
CREATE TABLE tbl_ORD_DTL_LN_ITM_2012 (
    ord_line_id INT PRIMARY KEY,
    fk_ord_id INT,
    int_line_num INT,
    fk_prd_id INT,
    vch_prd_code VARCHAR(50),
    vch_prd_name VARCHAR(200),
    int_qty_ordered INT,
    int_qty_shipped INT,
    int_qty_backordered INT,
    dec_unit_price DECIMAL(10,2),
    dec_discount_pct DECIMAL(5,2),
    dec_discount_amt DECIMAL(10,2),
    dec_tax_amt DECIMAL(10,2),
    dec_line_total DECIMAL(12,2),
    int_line_status_cd INT,
    dt_crt_dt TIMESTAMP
);

-- Order status history
CREATE TABLE TBL_ORD_STATUS_HIST (
    status_hist_id INT PRIMARY KEY,
    fk_ord_id INT,
    int_old_status_cd INT,
    int_new_status_cd INT,
    dt_status_change_dt TIMESTAMP,
    int_changed_by_usr_id INT,
    txt_change_reason TEXT
);

-- ============================================
-- INVENTORY MODULE
-- ============================================

-- Warehouse master
CREATE TABLE tbl_WH_MSTR_LOC (
    wh_id INT PRIMARY KEY,
    vch_wh_code VARCHAR(20),
    vch_wh_name VARCHAR(100),
    txt_addr_ln1 TEXT,
    txt_addr_ln2 TEXT,
    vch_city_nm VARCHAR(100),
    vch_state_cd VARCHAR(2),
    vch_zip_code VARCHAR(10),
    vch_phone_num VARCHAR(20),
    vch_manager_name VARCHAR(100),
    bit_is_active BIT,
    dt_opened_dt DATE,
    dt_crt_dt TIMESTAMP
);

-- Inventory transactions
CREATE TABLE tbl_INV_TXN_LOG_2015_v2 (
    txn_id INT PRIMARY KEY,
    fk_prd_id INT,
    fk_wh_id INT,
    vch_txn_type VARCHAR(20),
    int_qty_change INT,
    int_qty_before INT,
    int_qty_after INT,
    dec_unit_cost DECIMAL(10,2),
    dec_total_cost DECIMAL(12,2),
    vch_ref_doc_type VARCHAR(20),
    int_ref_doc_id INT,
    txt_txn_notes TEXT,
    dt_txn_dt TIMESTAMP,
    int_performed_by_usr_id INT
);

-- Stock levels by warehouse
CREATE TABLE TBL_INV_STOCK_LVL_WH (
    stock_lvl_id INT PRIMARY KEY,
    fk_prd_id INT,
    fk_wh_id INT,
    int_qty_on_hand INT,
    int_qty_allocated INT,
    int_qty_available INT,
    int_reorder_point INT,
    int_max_stock_lvl INT,
    dt_last_count_dt DATE,
    dt_last_upd_dt TIMESTAMP
);

-- ============================================
-- EMPLOYEE & SALES REP MODULE
-- ============================================

-- Employee master table
CREATE TABLE tbl_EMP_MSTR_HR_2010 (
    emp_id INT PRIMARY KEY,
    vch_emp_code VARCHAR(20),
    vch_f_name VARCHAR(50),
    vch_l_name VARCHAR(50),
    vch_email_addr VARCHAR(150),
    vch_phone_num VARCHAR(20),
    fk_dept_id INT,
    fk_mgr_id INT,
    vch_job_title VARCHAR(100),
    dt_hire_dt DATE,
    dt_term_dt DATE,
    dec_salary_amt DECIMAL(12,2),
    vch_emp_type VARCHAR(20),
    bit_is_active BIT,
    dt_birth_dt DATE,
    vch_ssn VARCHAR(11),
    txt_addr_ln1 TEXT,
    vch_city_nm VARCHAR(100),
    vch_state_cd VARCHAR(2),
    vch_zip_code VARCHAR(10),
    dt_crt_dt TIMESTAMP,
    dt_last_upd_dt TIMESTAMP
);

-- Sales territory
CREATE TABLE tbl_SALES_TERR_MSTR (
    territory_id INT PRIMARY KEY,
    vch_terr_code VARCHAR(20),
    vch_terr_name VARCHAR(100),
    txt_terr_desc TEXT,
    fk_region_id INT,
    fk_sales_mgr_id INT,
    bit_is_active BIT,
    dt_crt_dt TIMESTAMP
);

-- ============================================
-- PAYMENT & INVOICE MODULE
-- ============================================

-- Invoice header
CREATE TABLE tbl_INV_HDR_MSTR_2013 (
    inv_id INT PRIMARY KEY,
    vch_inv_num VARCHAR(50),
    fk_ord_id INT,
    fk_cust_id INT,
    dt_inv_dt DATE,
    dt_due_dt DATE,
    dec_subtotal_amt DECIMAL(12,2),
    dec_tax_amt DECIMAL(12,2),
    dec_total_amt DECIMAL(12,2),
    dec_paid_amt DECIMAL(12,2),
    dec_balance_amt DECIMAL(12,2),
    int_inv_status_cd INT,
    vch_payment_terms VARCHAR(50),
    txt_inv_notes TEXT,
    dt_crt_dt TIMESTAMP,
    dt_last_upd_dt TIMESTAMP
);

-- Payment transactions
CREATE TABLE TBL_PMT_TXN_LOG_2014 (
    pmt_id INT PRIMARY KEY,
    fk_inv_id INT,
    fk_cust_id INT,
    vch_pmt_ref VARCHAR(100),
    dec_pmt_amt DECIMAL(12,2),
    dt_pmt_dt DATE,
    vch_pmt_method VARCHAR(20),
    vch_card_type VARCHAR(20),
    vch_card_last4 VARCHAR(4),
    vch_auth_code VARCHAR(50),
    int_pmt_status_cd INT,
    txt_pmt_notes TEXT,
    dt_processed_dt TIMESTAMP,
    int_processed_by_usr_id INT
);

-- ============================================
-- LOOKUP & REFERENCE TABLES
-- ============================================

-- Status codes lookup
CREATE TABLE tbl_STATUS_CD_LKP (
    status_cd INT PRIMARY KEY,
    vch_status_type VARCHAR(50),
    vch_status_name VARCHAR(100),
    vch_status_desc VARCHAR(255),
    int_display_order INT,
    bit_is_active BIT
);

-- Country codes
CREATE TABLE TBL_COUNTRY_CD_REF (
    country_cd VARCHAR(3) PRIMARY KEY,
    vch_country_name VARCHAR(100),
    vch_iso2_code VARCHAR(2),
    vch_iso3_code VARCHAR(3),
    vch_phone_prefix VARCHAR(10),
    bit_is_active BIT
);

-- ============================================
-- AUDIT & SYSTEM TABLES
-- ============================================

-- User activity log
CREATE TABLE tbl_USR_ACTIVITY_LOG_2016 (
    log_id INT PRIMARY KEY,
    fk_usr_id INT,
    vch_activity_type VARCHAR(50),
    vch_table_name VARCHAR(100),
    int_record_id INT,
    txt_old_value TEXT,
    txt_new_value TEXT,
    vch_ip_addr VARCHAR(50),
    dt_activity_dt TIMESTAMP
);

-- System configuration
CREATE TABLE TBL_SYS_CFG_PARAMS (
    cfg_id INT PRIMARY KEY,
    vch_cfg_key VARCHAR(100),
    vch_cfg_value VARCHAR(500),
    vch_cfg_type VARCHAR(20),
    txt_cfg_desc TEXT,
    dt_last_upd_dt TIMESTAMP,
    int_upd_by_usr_id INT
);

-- Generated with IBM Bob for LegacyLink AI Hackathon
-- This schema demonstrates complex legacy patterns including:
-- - Multiple naming conventions (Hungarian, snake_case, mixed)
-- - Inconsistent prefixes (tbl_, TBL_, no prefix)
-- - Version suffixes (_v2, _v3, _2012, _FINAL)
-- - Abbreviated column names (vch_, int_, dec_, dt_, fk_, txt_, bit_)
-- - Complex foreign key relationships
-- - Multiple modules with interdependencies
-- - Audit trails and history tables
-- - Lookup and reference tables

-- Made with Bob
