# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependency file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
COPY fetch_product_usage.py .

# Define the entry point for the container. 
# We assume the orchestrator (ADF/ACI) will pass the necessary arguments 
# (start_date, end_date, secrets) via command line arguments.
CMD ["python", "fetch_product_usage.py"]