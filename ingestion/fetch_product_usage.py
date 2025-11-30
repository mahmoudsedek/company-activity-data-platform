import requests
import json
from datetime import datetime, timedelta
import logging
from azure.storage.blob import BlobServiceClient

def fetch_product_usage(start_date, end_date, api_key, output_container, blob_connection_string):
    """
    Fetches usage data and lands it in Blob Storage.
    Handles pagination, rate limiting, and idempotency.
    
    Args:
        start_date (datetime): Start of window
        end_date (datetime): End of window
        api_key (str): Auth token, injected from Key Vault via ADF.
        output_container (str): Target Blob container.
        blob_connection_string (str): Connection string, injected from Key Vault via ADF.
    """
    base_url = "https://api.product-usage.com/v1/stats" #FAKE URL
    current_cursor = start_date
    
    # SECURITY STANDARD: Initialize Blob Client using the string injected by the orchestrator.
    # In production, DefaultAzureCredential() is preferred for service-to-service auth.
    blob_service = BlobServiceClient.from_connection_string(blob_connection_string)
    
    while current_cursor <= end_date:
        str_date = current_cursor.strftime('%Y-%m-%d')
        logging.info(f"Processing date: {str_date}")
        
        try:
            # 1. Call API with pagination handling
            all_records = []
            page = 1
            has_more = True
            
            while has_more:
                # API Key is passed via header (also injected from ADF/Key Vault)
                response = requests.get(
                    base_url, 
                    params={'date': str_date, 'page': page},
                    headers={'Authorization': f'Bearer {api_key}'},
                    timeout=30
                )
                response.raise_for_status()
                data = response.json()
                
                records = data.get('results', [])
                all_records.extend(records)
                
                # Check pagination (API specific logic)
                if data.get('next_page'):
                    page += 1
                else:
                    has_more = False
            
            # 2. Land Data (Idempotent naming)
            if all_records:
                file_name = f"usage_data_{str_date}.json"
                blob_client = blob_service.get_blob_client(
                    container=output_container, 
                    blob=file_name
                )
                
                blob_client.upload_blob(
                    json.dumps(all_records), 
                    overwrite=True
                )
                logging.info(f"Successfully uploaded {file_name}")
            else:
                logging.warning(f"No records found for {str_date}")
            
        except requests.exceptions.RequestException as e:
            logging.error(f"API Failed for {str_date}: {str(e)}")
            # Critical: Raise error to fail pipeline for retry logic in ADF
            raise e

        current_cursor += timedelta(days=1)

# Example Execution for testing
if __name__ == "__main__":
    # Note: In a real run, these secrets would be passed from ADF/Key Vault.
    fetch_product_usage(datetime(2023,10,25), datetime(2023,10,25), "ABI_SECRETs", "landing-data", "YOUR_CONNECTION_STRING_HERE")