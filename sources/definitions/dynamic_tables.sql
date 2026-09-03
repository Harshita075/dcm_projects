-- ============================================================
-- 04_dynamic_tables.sql
-- The declarative "model" layer: a dynamic table that keeps
-- itself in sync with SALES_ORDERS automatically — no task,
-- no procedure call, no manual scheduling.
--
-- INITIALIZE = 'ON_SCHEDULE' skips the synchronous refresh at
-- CREATE time so `snow dcm deploy` stays fast; the table
-- populates itself in the background on its own schedule
-- (or via EXECUTE DCM PROJECT ... REFRESH ALL, see scripts/).
-- ============================================================

DEFINE DYNAMIC TABLE SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY
WAREHOUSE = SALES_WH{{env_suffix}}
TARGET_LAG = '1 minute'  -- 5 minutes
INITIALIZE = 'ON_SCHEDULE'
DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'
COMMENT = 'Declarative daily sales rollup - auto-refreshes as SALES_ORDERS changes'
AS
SELECT
    order_date                              AS summary_date,
    region,
    COUNT(DISTINCT order_id)                AS total_orders,
    SUM(quantity * unit_price)              AS total_revenue,
    AVG(quantity * unit_price)              AS avg_order_value
FROM SALES{{env_suffix}}_DB.RAW.SALES_ORDERS
GROUP BY order_date, region;

