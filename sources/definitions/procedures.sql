-- ============================================================
-- 03_procedures.sql
-- Stored procedure that rolls up raw orders into a daily summary.
-- Managed fully by DCM: edits here become ALTER PROCEDURE on
-- the next plan/deploy, no manual CREATE OR REPLACE needed.
--
-- This procedure is called either manually, from the scheduled
-- task in 05_tasks.sql, or you can skip it entirely and let the
-- dynamic table in 04_dynamic_tables.sql do the transformation
-- declaratively instead. Both patterns are shown so you can
-- compare them in the demo.
-- ============================================================

DEFINE PROCEDURE SALES{{env_suffix}}_DB.ANALYTICS.SALES_REFRESH()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
    DELETE FROM SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY_PROC
    WHERE summary_date = CURRENT_DATE();

    INSERT INTO SALES{{env_suffix}}_DB.ANALYTICS.DAILY_SALES_SUMMARY_PROC
        (summary_date, region, total_orders, total_revenue, refreshed_at)
    SELECT
        order_date,
        region,
        COUNT(DISTINCT order_id)               AS total_orders,
        SUM(quantity * unit_price)              AS total_revenue,
        CURRENT_TIMESTAMP()                     AS refreshed_at
    FROM SALES{{env_suffix}}_DB.RAW.SALES_ORDERS
    WHERE order_date = CURRENT_DATE()
    GROUP BY order_date, region;

    RETURN 'Sales summary refreshed for ' || CURRENT_DATE()::VARCHAR;
END;
$$;


