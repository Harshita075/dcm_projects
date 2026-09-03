-- ============================================================
-- 05_tasks.sql
-- Scheduled orchestration for the PROCEDURE-driven pattern.
-- The STARTED keyword is a DCM-only extension to DEFINE TASK:
-- it deploys the task already running, so no manual
-- ALTER TASK ... RESUME is needed after deploy.
--
-- Flip STARTED -> SUSPENDED in this file (and redeploy) to
-- pause the schedule declaratively, straight from Git.
-- ============================================================

DEFINE TASK SALES{{env_suffix}}_DB.ANALYTICS.SALES_REFRESH_TASK
    WAREHOUSE = SALES_WH{{env_suffix}}
    SCHEDULE = 'USING CRON 0 2 * * * UTC'   -- daily at 02:00 UTC
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    COMMENT = 'Nightly refresh of DAILY_SALES_SUMMARY_PROC via SALES_REFRESH procedure'
    STARTED
AS
    CALL SALES{{env_suffix}}_DB.ANALYTICS.SALES_REFRESH();