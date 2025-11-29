/* Target: fct_company_daily_activity
   Logic: Left Join CRM (Anchor) to Usage. Calculate rolling metrics.
   Grain: One row per company_id per date
*/

WITH
-- Parameters: define run date in target timezone
params AS (
    SELECT
        -- change timezone name to your client timezone if different
        CONVERT_TIMEZONE('UTC', 'America/New_York', CURRENT_TIMESTAMP())::DATE AS target_date
),

DailyUsage AS (
    -- Handle potential duplicates in source API data
    -- Aggregate after explicit timezone conversion so dates align with client expectations
    SELECT 
        company_id,
        DATE(CONVERT_TIMEZONE('UTC','America/New_York', date)) AS usage_date,
        SUM(active_users) as daily_active_users,
        SUM(events) as daily_events
    FROM stg_product_usage
    WHERE DATE(CONVERT_TIMEZONE('UTC','America/New_York', date)) = (SELECT target_date FROM params)
    GROUP BY company_id, DATE(CONVERT_TIMEZONE('UTC','America/New_York', date))
),

-- Guarantee one row per company × date (prevents "invisible churn")
CompanyDate AS (
    SELECT
        c.company_id,
        (SELECT target_date FROM params) AS activity_date
    FROM stg_crm_snapshot c
),

EnrichedData AS (
    SELECT
        cd.activity_date,
        c.company_id,
        c.name as company_name,
        c.country,
        c.industry_tag,
        -- Calculate days since contact dynamically
        DATEDIFF(day, c.last_contact_at, cd.activity_date) as days_since_last_contact,
        COALESCE(u.daily_active_users, 0) as active_users_count,
        COALESCE(u.daily_events, 0) as event_count
    FROM stg_crm_snapshot c
    JOIN CompanyDate cd ON c.company_id = cd.company_id
    LEFT JOIN DailyUsage u 
        ON c.company_id = u.company_id
)
SELECT
    *,
    -- Could be moved later to a separate model if needed (based on the performance)
    AVG(active_users_count) OVER (
        PARTITION BY company_id 
        ORDER BY activity_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as avg_7d_active_users,
    
    CASE 
        WHEN active_users_count = 0 AND days_since_last_contact > 30 THEN TRUE
        ELSE FALSE 
    END as is_churn_risk,
    
    CURRENT_TIMESTAMP() as ingested_at
FROM EnrichedData;