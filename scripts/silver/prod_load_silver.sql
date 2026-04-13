/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'silver' schema from the 'bronze' schema.
    It performs the following actions:
    - Truncates the silver tables before loading data.
    - Cleanses, standardizes, and transforms data from bronze tables.
    - Inserts validated data into the silver tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL silver.load_silver();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_time    timestamptz;
    v_end_time      timestamptz;
    v_duration      interval;
    v_msg           text;
    v_detail        text;
    v_hint          text;
BEGIN
    v_start_time := clock_timestamp();

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Loading Silver Layer';
    RAISE NOTICE 'Start time: %', v_start_time;
    RAISE NOTICE '=============================================';

    BEGIN
        RAISE NOTICE '---------------------------------------------';
        RAISE NOTICE 'Loading CRM Tables';
        RAISE NOTICE '---------------------------------------------';

        RAISE NOTICE '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        RAISE NOTICE '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY cst_id
                       ORDER BY cst_create_date DESC
                   ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE t.flag_last = 1;

        RAISE NOTICE '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        RAISE NOTICE '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt,
            dwh_create_date
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key FROM 7) AS prd_key,
            prd_nm,
            COALESCE(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END AS prd_line,
            prd_start_dt,
            LEAD(prd_start_dt) OVER (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            ) - 1 AS prd_end_dt,
            NOW() AS dwh_create_date
        FROM bronze.crm_prd_info;

        RAISE NOTICE '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        RAISE NOTICE '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE
                WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::text) <> 8 THEN NULL
                ELSE TO_DATE(sls_order_dt::text, 'YYYYMMDD')
            END AS sls_order_dt,
            CASE
                WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::text) <> 8 THEN NULL
                ELSE TO_DATE(sls_ship_dt::text, 'YYYYMMDD')
            END AS sls_ship_dt,
            CASE
                WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::text) <> 8 THEN NULL
                ELSE TO_DATE(sls_due_dt::text, 'YYYYMMDD')
            END AS sls_due_dt,
            CASE
                WHEN sls_sales IS NULL
                  OR sls_sales <= 0
                  OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE
                WHEN sls_price IS NULL OR sls_price < 0
                THEN ABS(sls_price) / NULLIF(sls_quantity, 0)
                ELSE ABS(sls_price)
            END AS sls_price
        FROM bronze.crm_sales_details;

    EXCEPTION
        WHEN OTHERS THEN
            v_end_time := clock_timestamp();
            v_duration := v_end_time - v_start_time;

            GET STACKED DIAGNOSTICS
                v_msg = MESSAGE_TEXT,
                v_detail = PG_EXCEPTION_DETAIL,
                v_hint = PG_EXCEPTION_HINT;

            RAISE NOTICE '=============================================';
            RAISE NOTICE 'CRM silver load failed';
            RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
            RAISE NOTICE 'Message: %', v_msg;
            RAISE NOTICE 'Detail: %', COALESCE(v_detail, 'none');
            RAISE NOTICE 'Hint: %', COALESCE(v_hint, 'none');
            RAISE NOTICE 'Start time: %', v_start_time;
            RAISE NOTICE 'Error time: %', v_end_time;
            RAISE NOTICE 'Elapsed time before failure: %', v_duration;
            RAISE NOTICE '=============================================';

            RAISE EXCEPTION 'CRM silver load failed. SQLSTATE: %, Message: %, Detail: %, Hint: %',
                SQLSTATE, v_msg, COALESCE(v_detail, 'none'), COALESCE(v_hint, 'none');
    END;

    BEGIN
        RAISE NOTICE '---------------------------------------------';
        RAISE NOTICE 'Loading ERP Tables';
        RAISE NOTICE '---------------------------------------------';

        RAISE NOTICE '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        RAISE NOTICE '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            CASE
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
                ELSE cid
            END AS cid,
            CASE
                WHEN bdate > NOW()::date THEN NULL
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'N/A'
            END AS gen
        FROM bronze.erp_cust_az12;

        RAISE NOTICE '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        RAISE NOTICE '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE
                WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'N/A'
                ELSE 'N/A'
            END AS cntry
        FROM bronze.erp_loc_a101;

        RAISE NOTICE '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        RAISE NOTICE '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM bronze.erp_px_cat_g1v2;

    EXCEPTION
        WHEN OTHERS THEN
            v_end_time := clock_timestamp();
            v_duration := v_end_time - v_start_time;

            GET STACKED DIAGNOSTICS
                v_msg = MESSAGE_TEXT,
                v_detail = PG_EXCEPTION_DETAIL,
                v_hint = PG_EXCEPTION_HINT;

            RAISE NOTICE '=============================================';
            RAISE NOTICE 'ERP silver load failed';
            RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
            RAISE NOTICE 'Message: %', v_msg;
            RAISE NOTICE 'Detail: %', COALESCE(v_detail, 'none');
            RAISE NOTICE 'Hint: %', COALESCE(v_hint, 'none');
            RAISE NOTICE 'Start time: %', v_start_time;
            RAISE NOTICE 'Error time: %', v_end_time;
            RAISE NOTICE 'Elapsed time before failure: %', v_duration;
            RAISE NOTICE '=============================================';

            RAISE EXCEPTION 'ERP silver load failed. SQLSTATE: %, Message: %, Detail: %, Hint: %',
                SQLSTATE, v_msg, COALESCE(v_detail, 'none'), COALESCE(v_hint, 'none');
    END;

    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Silver load completed successfully.';
    RAISE NOTICE 'Start time: %', v_start_time;
    RAISE NOTICE 'End time: %', v_end_time;
    RAISE NOTICE 'Total duration: %', v_duration;
    RAISE NOTICE '=============================================';
END;
$$;
