-- ============================================================
-- 02_tables.sql
-- Raw landing tables for the sales pipeline, plus the target
-- table for the PROCEDURE-driven refresh pattern.
--
-- CUSTOMERS and PRODUCTS are dimension tables: low-frequency
-- reference data, loaded once (or on a slow cadence) and joined
-- into the fact table. Unlike SALES_ORDERS, they deliberately do
-- NOT have CHANGE_TRACKING or a DATA_METRIC_SCHEDULE - not every
-- table needs to be reactive, only the ones driving refreshes.
--
-- SALES_ORDERS has CHANGE_TRACKING = TRUE so downstream dynamic
-- tables and data metric functions can react to inserts/updates
-- automatically.
-- ============================================================

DEFINE TABLE SALES{{env_suffix}}_DB.RAW.CUSTOMERS (
    customer_id       NUMBER            COMMENT 'Unique customer identifier',
    customer_name     VARCHAR           COMMENT 'Customer display name',
    segment           VARCHAR           COMMENT 'e.g. Enterprise, SMB, Consumer',
    signup_date       DATE              COMMENT 'Date customer first signed up',
    region            VARCHAR           COMMENT 'Customer home region',
    loaded_at         TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Ingestion timestamp'
)
COMMENT = 'Customer dimension - slowly changing, loaded once per demo run';

DEFINE TABLE SALES{{env_suffix}}_DB.RAW.PRODUCTS (
    product_id        NUMBER            COMMENT 'Unique product identifier',
    product_name      VARCHAR           COMMENT 'Product display name',
    category          VARCHAR           COMMENT 'e.g. Electronics, Apparel, Home',
    unit_cost         NUMBER(10,2)      COMMENT 'Cost basis, used for margin calc',
    loaded_at         TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Ingestion timestamp'
)
COMMENT = 'Product dimension - slowly changing, loaded once per demo run';

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