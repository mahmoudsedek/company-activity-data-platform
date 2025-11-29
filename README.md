# company-activity-data-platform

A scalable Azure-based data platform designed to ingest CRM and product usage data for churn analysis and activity tracking.

## Repository layout

- ingestion/          — Python API extraction scripts & ADF logic  
- modeling/           — SQL logic for Fact/Dimension creation  
- performance/        — Optimization strategies (Planned)  
- quality_checks/     — Data quality validation rules (Planned)  
- docs/               — Architecture diagrams & documentation

## Quickstart

Prerequisites:
- Python 3.8+ (for local scripts)
- An Azure subscription (for cloud deployment)
- Access to the target Snowflake/warehouse

Example local setup (Windows):
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1   # use Activate.bat for cmd
pip install -r ingestion/requirements.txt
```

## How to use

1. Populate secrets / connection strings (Environment variables or Azure Key Vault).
2. Run ingestion scripts from ingestion/ to load staging tables.
3. Run SQL models from modeling/ (via your orchestration tool or manually) to build facts and dimensions.
4. Check performance/ for optimization guidance and quality_checks/ for validation rules.

## Modeling notes

- model files live in modeling/
- fct_company_daily_activity.sql contains logic for daily company activity and rolling metrics
- Ensure timezone normalization when aggregating event timestamps

## Performance & Quality

- See performance/ for quick triage strategies and case studies
- Implement quality checks in quality_checks/ and integrate into CI

## Contributing

- Open an issue for design/bug discussions
- Submit PRs against main with tests and a short description
