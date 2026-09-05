-- ============================================================
-- 04_dynamic_tables.sql
-- The declarative "model" layer: dynamic tables that keep
-- themselves in sync automatically - no task, no procedure
-- call, no manual scheduling.
--
-- Two dynamic tables here, forming a small DAG:
--   SALES_ORDERS  ->  DAILY_SALES_SUMMARY  ->  TOP_PRODUCTS_BY_REVENUE
-- Snowflake tracks this dependency graph itself: an insert into
-- SALES_ORDERS refreshes DAILY_SALES_SUMMARY, which in turn
-- refreshes TOP_PRODUCTS_BY_REVENUE right behind it, in the
-- correct order, with no orchestration code anywhere.
--
-- INITIALIZE = 'ON_SCHEDULE' skips the synchronous refresh at
-- CREATE time so `snow dcm deploy` stays fast; each table
-- populates itself in the background on its own schedule
-- (or via EXECUTE DCM PROJECT ... REFRESH ALL, see scripts/).
-- ============================================================

DEFINE DYNAMIC TABLE SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY
WAREHOUSE = SALES_WH{{env_suffix}}
TARGET_LAG = '1 minute'
INITIALIZE = 'ON_SCHEDULE'
DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'
COMMENT = 'Declarative daily sales rollup - auto-refreshes as SALES_ORDERS changes'
AS
SELECT
    o.order_date                              AS summary_date,
    o.region,
    p.category                                AS product_category,
    c.segment                                 AS customer_segment,
    COUNT(DISTINCT o.order_id)                AS total_orders,
    SUM(o.quantity * o.unit_price)             AS total_revenue,
    AVG(o.quantity * o.unit_price)             AS avg_order_value
FROM SALES{{env_suffix}}_DB.RAW.SALES_ORDERS o
JOIN SALES{{env_suffix}}_DB.RAW.PRODUCTS p  ON o.product_id  = p.product_id
JOIN SALES{{env_suffix}}_DB.RAW.CUSTOMERS c ON o.customer_id = c.customer_id
GROUP BY o.order_date, o.region, p.category, c.segment;

-- ------------------------------------------------------------
-- Downstream dynamic table: reads DAILY_SALES_SUMMARY, not the
-- raw SALES_ORDERS table. This is the piece that demonstrates a
-- dynamic table DAG rather than a single flat table - Snowflake
-- refreshes this one automatically whenever DAILY_SALES_SUMMARY
-- changes, with no separate trigger or task required.
-- ------------------------------------------------------------
DEFINE DYNAMIC TABLE SALES{{env_suffix}}_DB.ANALYTICS.TOP_PRODUCTS_BY_REVENUE
WAREHOUSE = SALES_WH{{env_suffix}}
TARGET_LAG = '2 minutes'
INITIALIZE = 'ON_SCHEDULE'
COMMENT = 'Downstream rollup built on top of DAILY_SALES_SUMMARY - demonstrates dynamic table DAGs'
AS
SELECT
    product_category,
    SUM(total_revenue)                              AS category_revenue,
    SUM(total_orders)                               AS category_orders,
    RANK() OVER (ORDER BY SUM(total_revenue) DESC)  AS revenue_rank
FROM SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY
GROUP BY product_category;