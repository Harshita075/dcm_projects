-- ============================================================
-- 06_expectations.sql
-- Data quality expectations attached declaratively to the
-- dynamic table model layer. Because DAILY_SALES_SUMMARY has
-- DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES', these are
-- evaluated automatically every time the table refreshes.
--
-- Requires (granted once, outside DCM, to the deploying role):
--   GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_ADMIN TO ROLE <role>;
--   GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE <role>;
--   GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE <role>;
-- ============================================================


ATTACH DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT
    TO TABLE SALES{{env_suffix}}_DB.RAW.SALES_ORDERS
    ON (order_id)
    EXPECTATION NO_DUPLICATE_ORDER_IDS (VALUE = 0);
