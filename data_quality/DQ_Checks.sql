/*
Data Quality Checks for fact_company_daily_activity

These checks run after the daily transformation to ensure data integrity
and help debug "data mismatch" issues. They assume the presence of a 
system or control table to log results.
*/

-- Define the target date for the current pipeline run
WITH params AS (
    SELECT
        CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_TIMESTAMP())::DATE AS target_date
),

-- 1. Check Row Count Integrity
-- Checks if the number of fact rows inserted equals the total number of active companies.
CHECK_ROW_COUNT AS (
    SELECT
        'Row Count Integrity' AS check_name,
        (SELECT COUNT(DISTINCT company_id) FROM stg_crm_snapshot) AS expected_count,
        (SELECT COUNT(*) FROM fct_company_daily_activity 
         WHERE activity_date = (SELECT target_date FROM params)) AS actual_count
),

-- 2. Check Sum of Events Reconciliation
-- Checks if the total aggregated events in the fact table match the total events
-- from the raw, time-normalized staging data for the same day.
CHECK_SUM_RECONCILIATION AS (
    SELECT
        'Sum of Events Reconciliation' AS check_name,
        (SELECT SUM(daily_events) FROM (
            -- Re-calculate the sum from the raw staging table after filtering/deduplication
            SELECT SUM(events) AS daily_events
            FROM stg_product_usage
            WHERE DATE(CONVERT_TIMEZONE('UTC','America/New_York', date)) = (SELECT target_date FROM params)
        )) AS expected_sum,
        (SELECT SUM(event_count) FROM fct_company_daily_activity 
         WHERE activity_date = (SELECT target_date FROM params)) AS actual_sum
),

-- 3. Check Uniqueness of Primary Key
-- Ensures there are no duplicate (company_id, activity_date) pairs.
CHECK_UNIQUENESS AS (
    SELECT
        'Uniqueness Check (PK)' AS check_name,
        COUNT(*) AS total_rows,
        COUNT(DISTINCT company_id || '-' || activity_date) AS distinct_keys
    FROM fct_company_daily_activity
    WHERE activity_date = (SELECT target_date FROM params)
)

-- Final result: Log checks where actual != expected (or where total_rows != distinct_keys)
SELECT 
    check_name,
    expected_count AS expected_value,
    actual_count AS actual_value,
    CASE WHEN expected_count = actual_count THEN 'PASS' ELSE 'FAIL' END AS result
FROM CHECK_ROW_COUNT

UNION ALL

SELECT
    check_name,
    expected_sum AS expected_value,
    actual_sum AS actual_value,
    CASE WHEN expected_sum = actual_sum THEN 'PASS' ELSE 'FAIL' END AS result
FROM CHECK_SUM_RECONCILIATION

UNION ALL

SELECT
    check_name,
    total_rows AS expected_value, -- Expect total rows to equal distinct keys
    distinct_keys AS actual_value,
    CASE WHEN total_rows = distinct_keys THEN 'PASS' ELSE 'FAIL' END AS result
FROM CHECK_UNIQUENESS;