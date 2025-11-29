Performance & Data Quality Strategy
1. Optimization Plan (The "30-Minute" Triage)
Scenario: The daily job takes 3+ hours. We have 30 minutes to touch one file.
Rank 1: Add Incremental Filtering (WHERE clause)
Change: Modify the SQL to process only the current execution date, rather than rescanning full history.
Code: WHERE date = '{{ execution_date }}'
Why: This turns a full-table scan (O(N)) into a single-partition scan (O(1)). It provides the most drastic performance gain for the least effort.
Rank 2: Materialization Strategy
Change: If fact_events is a View, convert it to a Table.
Why: Views recompute on every read. Persisting the data avoids redundant calculation, especially if the dashboard is queried multiple times a day.
Rank 3: Partitioning (DDL Change)
Change: Ensure the target table is partitioned by date.
Why: This enables "Partition Pruning." However, re-writing an existing massive table to apply partitioning usually takes longer than 30 minutes to execute, which is why it is ranked 3rd.
2. SQL Logic Risks & Fixes
Snippet:
SELECT company_id, date, SUM(events) AS events
FROM fact_events
GROUP BY company_id, date;


Risk 1: The "Invisible Churn" (Missing Zeros)
Flaw: If a company has zero events for a day, they simply do not appear in fact_events. The SUM returns nothing, not 0.
Impact: The dashboard will show "No Data" instead of "0 Active Users," breaking the logic for our "Churn Risk" flag (which looks for 0 activity).
Fix: Use a CROSS JOIN between a calendar table and a distinct list of companies, then LEFT JOIN the events to force a row of 0 for inactive days.
Risk 2: Timezone Truncation
Flaw: If date is derived from a UTC timestamp but the client is in EST, events occurring at 8 PM EST might be attributed to "tomorrow" (UTC).
Fix: Explicitly convert timezones before truncating to date: DATE(CONVERT_TIMEZONE('UTC', 'America/New_York', event_timestamp)).
Risk 3: Upstream Duplication
Flaw: Raw API streams often send duplicate webhooks. A simple SUM will double-count these.
Fix: Apply deduplication logic (e.g., QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY ingested_at DESC) = 1) before aggregation.
3. Real-World Performance Case Study
Issue:
In a previous project at Valeo, we utilized an AWS Step Function pipeline where data transformation was handled by a batch component running on AWS Fargate. The execution time was becoming unsustainable, hitting 1.5 hours per run.
Investigation:
Resource Utilization: Monitoring CloudWatch metrics revealed that the Fargate containers were hitting CPU limits/Memory ceilings, indicating vertical scaling constraints.
Bottleneck Analysis: The scripts were running sequentially or with limited parallelism on a single node (container), failing to utilize distributed computing patterns for the growing dataset.
Action:
I migrated the transformation logic from the containerized scripts to AWS Glue.
This shifted the architecture from a single-node constrained environment to a serverless, distributed Apache Spark environment.
Result:
The pipeline execution time dropped by 40%.
This was primarily due to Glue's ability to parallelize the data shuffle and processing across multiple worker nodes, compared to the linear execution of the Fargate container.
