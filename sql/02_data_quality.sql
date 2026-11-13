-- 02_data_quality.sql
-- One row per check, so the data-quality log can be read (and tested) like any other table.

CREATE OR REPLACE TABLE dq_checks AS
WITH totals AS (
    SELECT count(*) AS n FROM stg_lodgements
),
checks AS (
    SELECT 'rows loaded' AS check_name, count(*) AS rows_affected FROM raw_lodgements
    UNION ALL
    SELECT 'unparseable lodgement date', count(*) FROM stg_lodgements WHERE lodgement_date IS NULL
    UNION ALL
    SELECT 'unparseable postcode', count(*) FROM stg_lodgements WHERE postcode IS NULL
    UNION ALL
    SELECT 'postcode outside NSW range 2000-2999', count(*) FROM stg_lodgements
        WHERE postcode NOT BETWEEN 2000 AND 2999
    UNION ALL
    SELECT 'dwelling type unknown (U)', count(*) FROM stg_lodgements WHERE dwelling_type = 'Unknown'
    UNION ALL
    SELECT 'dwelling type invalid code', count(*) FROM stg_lodgements WHERE dwelling_type = 'Invalid code'
    UNION ALL
    SELECT 'dwelling/bedroom columns swapped (fixed)', count(*) FROM stg_lodgements WHERE cols_swapped
    UNION ALL
    SELECT 'bedrooms unknown', count(*) FROM stg_lodgements WHERE bedrooms IS NULL
    UNION ALL
    SELECT 'bedrooms above 10', count(*) FROM stg_lodgements WHERE bedrooms > 10
    UNION ALL
    SELECT 'weekly rent unknown (U)', count(*) FROM stg_lodgements WHERE weekly_rent IS NULL
    UNION ALL
    SELECT 'weekly rent outside $50-$5,000 (flagged)', count(*) FROM stg_lodgements WHERE rent_outlier
    UNION ALL
    SELECT 'rows in analysis view v_residential', count(*) FROM v_residential
)
SELECT
    check_name,
    rows_affected,
    round(100.0 * rows_affected / (SELECT n FROM totals), 2) AS pct_of_rows
FROM checks;
