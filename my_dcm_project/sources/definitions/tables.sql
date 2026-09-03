-- ============================================================
-- 02_tables.sql
-- Raw landing table for sales order data.
-- CHANGE_TRACKING is required so downstream dynamic tables and
-- data metric functions can react to inserts/updates automatically.
-- ============================================================

DEFINE TABLE SALES{{env_suffix}}_DB.RAW.SALES_ORDERS (
    order_id        NUMBER            COMMENT 'Unique order identifier',
    order_date      DATE              COMMENT 'Date the order was placed',
    customer_id     NUMBER            COMMENT 'Customer identifier',
    product_id      NUMBER            COMMENT 'Product identifier',
    quantity        NUMBER            COMMENT 'Units ordered',
    unit_price      NUMBER(10,2)      COMMENT 'Price per unit at time of order',
    region          VARCHAR           COMMENT 'Sales region',
    loaded_at       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Ingestion timestamp',
    custom_attributes VARIANT  COMMENT 'Optional JSON blob for additional order attributes'
)
CHANGE_TRACKING = TRUE
DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES'
COMMENT = 'Raw landing table for sales order data';

-- ------------------------------------------------------------
-- Target table for the PROCEDURE-driven refresh pattern
-- (populated by SALES_REFRESH in 03_procedures.sql, on a
-- schedule via the task in 05_tasks.sql). Kept separate from
-- the DYNAMIC TABLE model below so both patterns can be
-- compared side by side in the demo.
-- ------------------------------------------------------------
DEFINE TABLE SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY_PROC (
    summary_date    DATE            COMMENT 'Day being summarized',
    region          VARCHAR         COMMENT 'Sales region',
    total_orders    NUMBER          COMMENT 'Distinct order count for the day/region',
    total_revenue   NUMBER(18,2)    COMMENT 'Total revenue for the day/region',
    refreshed_at    TIMESTAMP_LTZ   COMMENT 'When this row was last (re)computed'
)
COMMENT = 'Daily sales rollup populated by the SALES_REFRESH procedure';

