/*
===============================================================================
Data Quality Checks – Gold Layer
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and correctness of the Gold layer (star schema).

    It validates:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Data model connectivity for analytical queries.

Usage:
    - Execute each block separately (or the whole file) in DBeaver.
    - Any returned rows indicate potential data quality issues that must be
      investigated and resolved.
===============================================================================
*/


/******************************************************************************
 * 1. DIMENSION KEYS – UNIQUENESS
 *    Expectation: no rows returned.
 *    - Surrogate keys in dimensions should be unique.
 ******************************************************************************/

/* 1.1 gold.dim_customers: duplicate customer_key */
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

/* 1.2 gold.dim_products: duplicate product_key */
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;


/******************************************************************************
 * 2. FACT → DIMENSIONS – REFERENTIAL INTEGRITY
 *    Expectation: no rows returned.
 *    - Every fact row should successfully join to both customer and product
 *      dimensions by surrogate key.
 ******************************************************************************/

/* 2.1 gold.fact_sales: fact rows with missing dimension references */
SELECT
    f.order_number,
    f.customer_key,
    f.product_key,
    c.customer_key AS dim_customer_key,
    p.product_key AS dim_product_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
       ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
       ON p.product_key = f.product_key
WHERE c.customer_key IS NULL
   OR p.product_key IS NULL;


/******************************************************************************
 * 3. OPTIONAL: BASIC FACT TABLE SANITY CHECKS
 *    (Add as needed – e.g., negative sales, zero quantities)
 *    Expectation: typically no rows, or only known/justified exceptions.
 ******************************************************************************/

/* 3.1 gold.fact_sales: negative or zero sales/quantity (optional rule) */
SELECT
     order_number,
     quantity,
     price,
     sales
FROM gold.fact_sales
WHERE quantity <= 0
   OR sales    <= 0;
