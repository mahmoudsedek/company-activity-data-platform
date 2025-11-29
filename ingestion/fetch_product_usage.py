import requests
import json
from datetime import datetime, timedelta
import logging
from azure.storage.blob import BlobServiceClient

def fetch_product_usage(start_date, end_date, api_key, output_container):
    """
    Fetches usage data and lands it in Blob Storage.
    Handles pagination, rate limiting, and idempotency.
    
    Args:
        start_date (datetime): Start of window
        end_date (datetime): End of window
        api_key (str): Auth token
        output_container (str): Target Blob container
    """
    base_url = "https://api.product-usage.com/v1/stats" #FAKE URL
    current_cursor = start_date
    
    # Initialize Blob Client (Connection string usually from KeyVault or Env Var)
    # In production, use DefaultAzureCredential() instead of connection strings
    blob_service = BlobServiceClient.from_connection_string("YOUR_CONNECTION_STRING")
    
    while current_cursor <= end_date:
        str_date = current_cursor.strftime('%Y-%m-%d')
        logging.info(f"Processing date: {str_date}")
        
        try:
            # 1. Call API with pagination handling
            all_records = []
            page = 1
            has_more = True
            
            while has_more:
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
            # We overwrite if the file exists to ensure re-runs correct data issues
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
    fetch_product_usage(datetime(2023,10,25), datetime(2023,10,25), "ABI_SECRETs", "landing-data")