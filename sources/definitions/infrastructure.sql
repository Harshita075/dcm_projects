-- ============================================================
-- 01_infrastructure.sql
-- Defines the warehouse, database, and schemas for the sales pipeline.
-- Rendered per-environment via {{env_suffix}} and {{wh_size}}
-- from manifest.yml (DEV -> _DEV, UAT -> _UAT, PROD -> "").
-- ============================================================

DEFINE WAREHOUSE SALES_WH{{env_suffix}}
    WAREHOUSE_SIZE = '{{wh_size}}'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for the sales DCM pipeline';

DEFINE DATABASE SALES{{env_suffix}}_DB
    COMMENT = 'Sales data pipeline - managed by DCM Project';

DEFINE SCHEMA SALES{{env_suffix}}_DB.RAW
    COMMENT = 'Landing zone for raw sales data';

DEFINE SCHEMA SALES{{env_suffix}}_DB.ANALYTICS
    COMMENT = 'Transformed / modeled sales data (dynamic tables, procedures)';
