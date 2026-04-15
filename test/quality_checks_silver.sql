/*
===============================================================================
Data Quality Checks – Bronze & Silver Layers
===============================================================================
Script Purpose:
    This script runs “expect no results” data quality checks on the
    Bronze and Silver layers.

    It validates:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardisation and consistency (codes / allowed values).
    - Invalid date ranges and ordering.
    - Data consistency between related numeric fields.
    - High-level sanity checks (row counts).

Usage:
    - Execute each block separately (or the whole file) in DBeaver.
    - Any returned rows indicate potential data quality issues that must be
      investigated and resolved.
===============================================================================
*/


/******************************************************************************
 * 1. NULL OR DUPLICATE PRIMARY KEYS
 *    Expectation: no rows returned.
 *    Example: sls_ord_num should be NOT NULL and unique.
 ******************************************************************************/

/* 1.1 bronze.crm_sales_details: null or duplicate sls_ord_num */
SELECT
    sls_ord_num,
    COUNT(*) AS cnt
FROM bronze.crm_sales_details
GROUP BY sls_ord_num
HAVING sls_ord_num IS NULL
    OR COUNT(*) > 1;


/******************************************************************************
 * 2. UNWANTED SPACES IN STRING FIELDS
 *    Expectation: no rows returned.
 *    Checks for leading/trailing spaces by comparing value to TRIM(value).
 ******************************************************************************/

/* 2.1 bronze.crm_sales_details: product key with extra spaces */
SELECT sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key IS NOT NULL
  AND sls_prd_key <> TRIM(sls_prd_key);

/* 2.2 bronze.crm_sales_details: customer id with extra spaces */
SELECT sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id IS NOT NULL
  AND sls_cust_id <> TRIM(sls_cust_id);

/* 2.3 bronze.crm_prd_info: product key/name with extra spaces */
SELECT prd_key, prd_nm
FROM bronze.crm_prd_info
WHERE (prd_key IS NOT NULL AND prd_key <> TRIM(prd_key))
   OR (prd_nm  IS NOT NULL AND prd_nm  <> TRIM(prd_nm));

/* 2.4 bronze.crm_cust_info: customer names with extra spaces */
SELECT cst_id, cst_firstname, cst_lastname
FROM bronze.crm_cust_info
WHERE (cst_firstname IS NOT NULL AND cst_firstname <> TRIM(cst_firstname))
   OR (cst_lastname  IS NOT NULL AND cst_lastname  <> TRIM(cst_lastname));

/* 2.5 bronze.erp_cust_az12: customer id and gender with extra spaces */
SELECT cid, gen
FROM bronze.erp_cust_az12
WHERE (cid IS NOT NULL AND cid <> TRIM(cid))
   OR (gen IS NOT NULL AND gen <> TRIM(gen));

/* 2.6 bronze.erp_loc_a101: country codes with extra spaces */
SELECT cid, cntry
FROM bronze.erp_loc_a101
WHERE cntry IS NOT NULL
  AND cntry <> TRIM(cntry);


/******************************************************************************
 * 3. DATA STANDARDISATION & CONSISTENCY (CODES / ALLOWED VALUES)
 *    Expectation: no rows returned.
 *    Checks for unexpected values in code-like fields.
 ******************************************************************************/

/* 3.1 bronze.crm_prd_info: unexpected product line codes */
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info
WHERE prd_line IS NOT NULL
  AND UPPER(TRIM(prd_line)) NOT IN ('M','R','S','T');

/* 3.2 bronze.crm_cust_info: unexpected marital status codes */
SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info
WHERE cst_marital_status IS NOT NULL
  AND UPPER(TRIM(cst_marital_status)) NOT IN ('S','M');

/* 3.3 bronze.crm_cust_info: unexpected gender codes */
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr IS NOT NULL
  AND UPPER(TRIM(cst_gndr)) NOT IN ('F','M');

/* 3.4 bronze.erp_cust_az12: unexpected gender values */
SELECT DISTINCT gen
FROM bronze.erp_cust_az12
WHERE gen IS NOT NULL
  AND UPPER(TRIM(gen)) NOT IN ('F','M','FEMALE','MALE');

/* 3.5 bronze.erp_loc_a101: unexpected country codes */
SELECT DISTINCT cntry
FROM bronze.erp_loc_a101
WHERE cntry IS NOT NULL
  AND TRIM(cntry) NOT IN ('DE','US','USA');


/******************************************************************************
 * 4. INVALID DATES AND DATE ORDERING
 *    Expectation: no rows returned.
 *    Bronze:
 *      - Dates stored as 8‑digit integers (YYYYMMDD), check range/format.
 *    Silver:
 *      - Dates stored as DATE, check logical ordering.
 ******************************************************************************/

/* 4.1 bronze.crm_sales_details: raw order dates invalid */
SELECT sls_ord_num, sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt IS NULL
   OR sls_order_dt <= 0
   OR LENGTH(sls_order_dt::text) <> 8
   OR sls_order_dt < 19000101
   OR sls_order_dt > 20501231;

/* 4.2 bronze.crm_sales_details: raw ship dates invalid */
SELECT sls_ord_num, sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt IS NULL
   OR sls_ship_dt <= 0
   OR LENGTH(sls_ship_dt::text) <> 8
   OR sls_ship_dt < 19000101
   OR sls_ship_dt > 20501231;

/* 4.3 bronze.crm_sales_details: raw due dates invalid */
SELECT sls_ord_num, sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt IS NULL
   OR sls_due_dt <= 0
   OR LENGTH(sls_due_dt::text) <> 8
   OR sls_due_dt < 19000101
   OR sls_due_dt > 20501231;

/* 4.4 silver.crm_sales_details: invalid date ordering (expect no rows) */
SELECT
    sls_ord_num,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt
FROM silver.crm_sales_details
WHERE sls_order_dt IS NOT NULL
  AND (
        (sls_ship_dt IS NOT NULL AND sls_ship_dt < sls_order_dt) OR
        (sls_due_dt  IS NOT NULL AND sls_due_dt  < sls_order_dt) OR
        (sls_ship_dt IS NOT NULL AND sls_due_dt IS NOT NULL AND sls_ship_dt > sls_due_dt)
      );


/******************************************************************************
 * 5. DATA CONSISTENCY BETWEEN RELATED FIELDS
 *    Expectation: no rows returned.
 *    Examples:
 *      - Sales vs quantity × price.
 *      - Negative or zero values where not expected.
 ******************************************************************************/

/* 5.1 bronze.crm_sales_details: negative/null quantities, prices, or sales */
SELECT
    sls_ord_num,
    sls_quantity,
    sls_price,
    sls_sales
FROM bronze.crm_sales_details
WHERE sls_quantity IS NULL
   OR sls_price    IS NULL
   OR sls_sales    IS NULL
   OR sls_quantity < 0
   OR sls_price    = 0          -- treat zero price as suspicious
   OR sls_sales    <= 0;

/* 5.2 bronze.crm_sales_details: sales not equal to quantity * price */
SELECT
    sls_ord_num,
    sls_quantity,
    sls_price,
    sls_sales,
    sls_quantity * sls_price AS expected_sales
FROM bronze.crm_sales_details
WHERE sls_quantity IS NOT NULL
  AND sls_price    IS NOT NULL
  AND sls_sales    IS NOT NULL
  AND sls_quantity * sls_price <> sls_sales;

/* 5.3 bronze.crm_sales_details: sign mismatch between sales and price */
SELECT
    sls_ord_num,
    sls_quantity,
    sls_price,
    sls_sales
FROM bronze.crm_sales_details
WHERE sls_sales IS NOT NULL
  AND sls_price IS NOT NULL
  AND SIGN(sls_sales) <> SIGN(sls_price);


/******************************************************************************
 * 6. OPTIONAL: ROW COUNTS / SANITY CHECKS
 *    Not strict data-quality rules, but useful for monitoring.
 ******************************************************************************/

/* 6.1 Total row counts per key Bronze/ERP table */
SELECT 'crm_sales_details' AS table_name, COUNT(*) AS row_count
FROM bronze.crm_sales_details
UNION ALL
SELECT 'crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL
SELECT 'crm_cust_info', COUNT(*) FROM bronze.crm_cust_info
UNION ALL
SELECT 'erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
UNION ALL
SELECT 'erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
UNION ALL
SELECT 'erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;
