# company-activity-data-platform

A scalable Azure-based data platform designed to ingest CRM and product usage data for churn analysis and activity tracking.

## Repository layout

- docker/             — Dockerfile and dependencies for containerized components
- docs/               — Architecture diagrams & documentation
- ingestion/          — Python API extraction scripts & ADF logic  
- modeling/           — SQL logic for Fact/Dimension creation  
- performance/        — Optimization strategies (Planned)  
- quality_checks/     — Data quality validation rules (Planned)  

## Quickstart

Prerequisites:
- Python 3.8+ (for local scripts)
- Docker installed (for containerization)
- An Azure subscription (for cloud deployment)
- Access to the target Snowflake/warehouse

Example local setup (Windows):
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1   # use Activate.bat for cmd
pip install -r ingestion/requirements.txt
```

## Building the Docker Image
To containerize the ingestion process, run the following from the repository root:

# Build the image using the Dockerfile in the docker/ directory
docker build -t company-activity-ingest:latest -f docker/Dockerfile .

# Push the image to Azure Container Registry (ACR) for deployment
docker push youracr.azurecr.io/company-activity-ingest:latest


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
