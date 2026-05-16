-- Legacy Customer Master Table
-- Created: 2012
-- Last Modified: 2015

CREATE TABLE tbl_CUST_MSTR_2012_v2 (
    c_id INT PRIMARY KEY,
    vch_fname VARCHAR(50),
    vch_lname VARCHAR(50),
    vch_email VARCHAR(100),
    fk_str_id INT,
    dt_upd_dt TIMESTAMP,
    dt_crt_dt TIMESTAMP,
    int_status INT
);

-- Legacy Store Table
CREATE TABLE tbl_STR_MSTR (
    str_id INT PRIMARY KEY,
    vch_str_name VARCHAR(100),
    vch_addr VARCHAR(200),
    vch_city VARCHAR(50),
    vch_state VARCHAR(2),
    vch_zip VARCHAR(10)
);

-- Legacy Order Table
CREATE TABLE tbl_ORD_DTL_2015 (
    ord_id INT PRIMARY KEY,
    fk_cust_id INT,
    fk_str_id INT,
    dec_amt DECIMAL(10,2),
    int_qty INT,
    dt_ord_dt TIMESTAMP
);

-- Made with Bob
