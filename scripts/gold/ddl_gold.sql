/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================

CREATE OR REPLACE PROCEDURE gold.load_gold()
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
    RAISE NOTICE 'Loading Gold Layer (creating views)';
    RAISE NOTICE 'Start time: %', v_start_time;
    RAISE NOTICE '=============================================';

    BEGIN
        RAISE NOTICE '---------------------------------------------';
        RAISE NOTICE 'Creating Dimension Views';
        RAISE NOTICE '---------------------------------------------';

        ----------------------------------------------------------------------
        -- Create Dimension: gold.dim_customers
        ----------------------------------------------------------------------
        RAISE NOTICE '>> Creating View: gold.dim_customers';
        CREATE OR REPLACE VIEW gold.dim_customers AS
        SELECT
            ROW_NUMBER() OVER (ORDER BY cci.cst_id) AS customer_key,   -- surrogate key
            cci.cst_id                  AS customer_id,
            cci.cst_key                 AS customer_number,
            cci.cst_firstname           AS first_name,
            cci.cst_lastname            AS last_name,
            ela.cntry                   AS country,
            cci.cst_marital_status      AS marital_status,
            CASE
                WHEN cci.cst_gndr <> 'N/A' THEN cci.cst_gndr
                ELSE COALESCE(eca.gen, 'N/A')
            END                        AS gender,
            eca.bdate                  AS birthdate,
            cci.cst_create_date        AS create_date
        FROM silver.crm_cust_info     cci
        LEFT JOIN silver.erp_cust_az12 eca
               ON cci.cst_key = eca.cid
        LEFT JOIN silver.erp_loc_a101 ela
               ON cci.cst_key = ela.cid;

        ----------------------------------------------------------------------
        -- Create Dimension: gold.dim_products
        ----------------------------------------------------------------------
        RAISE NOTICE '>> Creating View: gold.dim_products';
        CREATE OR REPLACE VIEW gold.dim_products AS
        SELECT
            ROW_NUMBER() OVER (
                ORDER BY cpi.prd_start_dt, cpi.prd_key
            )                           AS product_key,   -- surrogate key
            cpi.prd_id                  AS product_id,
            cpi.prd_key                 AS product_number,
            cpi.prd_nm                  AS product_name,
            cpi.cat_id                  AS category_id,
            epcgv.cat                   AS category,
            epcgv.subcat                AS subcategory,
            epcgv.maintenance           AS maintenance,
            cpi.prd_cost                AS cost,
            cpi.prd_line                AS product_line,
            cpi.prd_start_dt            AS start_date
        FROM silver.crm_prd_info       cpi
        LEFT JOIN silver.erp_px_cat_g1v2 epcgv
               ON cpi.cat_id = epcgv.id
        WHERE cpi.prd_end_dt IS NULL;

        ----------------------------------------------------------------------
        -- Create Fact: gold.fact_sales
        ----------------------------------------------------------------------
        RAISE NOTICE '>> Creating View: gold.fact_sales';
        CREATE OR REPLACE VIEW gold.fact_sales AS
        SELECT
            csd.sls_ord_num         AS order_number,
            gp.product_key          AS product_key,
            gc.customer_key         AS customer_key,
            csd.sls_order_dt        AS order_date,
            csd.sls_ship_dt         AS shipping_date,
            csd.sls_due_dt          AS due_date,
            csd.sls_sales           AS sales,
            csd.sls_quantity        AS quantity,
            csd.sls_price           AS price
        FROM silver.crm_sales_details csd
        LEFT JOIN gold.dim_products  gp
               ON csd.sls_prd_key = gp.product_number
        LEFT JOIN gold.dim_customers gc
               ON csd.sls_cust_id = gc.customer_id;

    EXCEPTION
        WHEN OTHERS THEN
            v_end_time := clock_timestamp();
            v_duration := v_end_time - v_start_time;

            GET STACKED DIAGNOSTICS
                v_msg = MESSAGE_TEXT,
                v_detail = PG_EXCEPTION_DETAIL,
                v_hint = PG_EXCEPTION_HINT;

            RAISE NOTICE '=============================================';
            RAISE NOTICE 'Gold layer load failed (view creation)';
            RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
            RAISE NOTICE 'Message: %', v_msg;
            RAISE NOTICE 'Detail: %', COALESCE(v_detail, 'none');
            RAISE NOTICE 'Hint: %', COALESCE(v_hint, 'none');
            RAISE NOTICE 'Start time: %', v_start_time;
            RAISE NOTICE 'Error time: %', v_end_time;
            RAISE NOTICE 'Elapsed time before failure: %', v_duration;
            RAISE NOTICE '=============================================';

            RAISE EXCEPTION 'Gold layer load failed. SQLSTATE: %, Message: %, Detail: %, Hint: %',
                SQLSTATE, v_msg, COALESCE(v_detail, 'none'), COALESCE(v_hint, 'none');
    END;

    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Gold load completed successfully (views created).';
    RAISE NOTICE 'Start time: %', v_start_time;
    RAISE NOTICE 'End time: %', v_end_time;
    RAISE NOTICE 'Total duration: %', v_duration;
    RAISE NOTICE '=============================================';
END;
$$;
