# Pipeline Architecture & Implementation Strategy

## 1. Azure Data Factory (ADF) Flow (Question 3)

Conceptual Sketch

The pipeline follows a standard "Extract-Load-Transform" (ELT) pattern. We separate the ingestion of the API (Python) and the CRM (CSV) but validate both before merging.

graph TD
    A[Trigger: Schedule Daily] --> B{Parallel Execution}
    B --> C[Web Activity: API Ingest]
    B --> D[Copy Activity: CRM Blob to SQL]
    
    C -- "Success (Writes JSON to Lake)" --> E{Validation Check}
    D -- "Success (Writes to Staging Table)" --> E
    
    E -- "Both Sources Ready" --> F[Transformation: Merge Logic]
    F --> G[End: Success]
    
    C -. "Fail" .-> H[Web Activity: Slack/Teams Alert]
    D -. "Fail" .-> H
    F -. "Fail" .-> H


# Component Details

## 1. Trigger: TRG_Daily_0100

Schedule: Daily at 1:00 AM UTC.

Parameters: windowStart passed to pipeline to ensure we fetch the correct data date.

## 2. API Ingestion (Python Wrapper): ACT_FUNC_IngestProductUsage

Type: Azure Function Activity (or Databricks Notebook Activity).

Why: The API requires pagination and logic too complex for a simple ADF Web Activity.

Target: Azure Function running the fetch_product_usage.py script.

Security Standard: All sensitive parameters (API Key, Connection Strings) are retrieved from Azure Key Vault by the ADF pipeline and passed securely as parameters to this activity.

Output: Raw JSON files in adls/raw/usage/{yyyy}/{mm}/{dd}/.

## 3. CRM Ingestion: ACT_COPY_CRMSnapshot

Type: Copy Data Activity.

Source: Azure Blob Storage (CSV format).

Sink: Azure SQL Database (Staging Table: stg_crm_snapshot).

Optimization: Truncate table before load (full snapshot).

## 4. Transformation: ACT_SQL_MergeDailyFacts

Type: Stored Procedure or Script Activity.

Logic: Executes the SQL found in modeling/transform_fact_activity.sql.

Dependencies: Only runs if both previous activities succeeded.

## 5. Alerting: ACT_WEB_SendAlert

Type: Web Activity.

Logic: POST request to a Logic App or Slack Webhook.

Error Handling Standard: The payload explicitly captures the error message from the failed activity (e.g., ACT_SQL_MergeDailyFacts) for immediate triage.

Payload:

{
  "pipeline": "PL_CompanyActivity",
  "status": "Failed",
  "activity_failed": "ACT_SQL_MergeDailyFacts",
  "error_detail": "@{activity('ACT_SQL_MergeDailyFacts').error.message}",
  "run_id": "@{pipeline().RunId}"
}



# 2. Triage Strategy: The "30-Minute Rule" (Challenge Question 5)

Scenario: You have 30 minutes before the deadline. You cannot finish everything.

The Decision
Implement First: The Extraction Layer (Ingestion)
Specifics: The Python API script (ingestion/fetch_product_usage.py) and the CRM Copy Activity.
Why: 1. Data Volatility: API data often changes or becomes harder to access over time (rate limits, window restrictions). If we miss the "T-0" ingestion window, that data might be lost forever.
1. Decoupling: Storage is cheap. We can land the raw data now (preservation) and figure out the complex SQL transformation logic later. We can replay transformations; we cannot replay a missed real-time event capture easily.
Explicitly Postponed: Complex Transformations & Rolling Metrics
Specifics: The 7-day rolling average SQL window functions and the "Churn Risk" derived logic.
Why: 1. History Dependency: Rolling averages need 7 days of history to be accurate. On Day 1, this metric is mathematically impossible or misleading (cold start).
2. Complexity: Debugging SQL window functions takes time. It is safer to ship a "Daily Active Users" (Raw Count) report that is 100% accurate than a "Churn Risk" report that is broken because of missing history.