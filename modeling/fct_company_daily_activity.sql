/* Target: fact_company_daily_activity
   Logic: Left Join CRM (Anchor) to Usage. Calculate rolling metrics.
   Grain: One row per company_id per date
*/

WITH DailyUsage AS (
    -- Handle potential duplicates in source API data
    -- Aggregating to ensure grain is respected even if API sends multiple payloads
    SELECT 
        company_id,
        date as usage_date,
        SUM(active_users) as daily_active_users,
        SUM(events) as daily_events
    FROM stg_product_usage
    WHERE usage_date = CURRENT_DATE() -- Assuming daily run
    GROUP BY company_id, usage_date
),
EnrichedData AS (
    SELECT
        CURRENT_DATE() as activity_date,
        c.company_id,
        c.name as company_name,
        c.country,
        c.industry_tag,
        -- Calculate days since contact dynamically
        DATEDIFF(day, c.last_contact_at, CURRENT_DATE()) as days_since_last_contact,
        COALESCE(u.daily_active_users, 0) as active_users_count,
        COALESCE(u.daily_events, 0) as event_count
    FROM stg_crm_snapshot c
    LEFT JOIN DailyUsage u 
        ON c.company_id = u.company_id
)
SELECT
    *,
    -- Derived Metric: 7 Day Moving Average
    -- Note: In a real incremental run, we'd look back at the target table history.
    -- Here we demonstrate the logic assuming we have the window in memory or staging.
    AVG(active_users_count) OVER (
        PARTITION BY company_id 
        ORDER BY activity_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as avg_7d_active_users,
    
    -- Derived Metric: Churn Risk Flag
    -- Risk logic: Zero active users AND no contact for 30+ days
    CASE 
        WHEN active_users_count = 0 AND days_since_last_contact > 30 THEN TRUE
        ELSE FALSE 
    END as is_churn_risk,
    
    CURRENT_TIMESTAMP() as ingested_at
FROM EnrichedData;
