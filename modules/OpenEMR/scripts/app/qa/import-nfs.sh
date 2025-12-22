#!/bin/bash
# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License. 

set -x

# Remove spaces from the region variables
APP_REGION_1=$(echo "us-central1" | tr -d '[:space:]')
APP_REGION_2=$(echo "" | tr -d '[:space:]')

# Maximum number of attempts
max_attempts=10
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false # Flag to track if any services were found

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "appopenermdemof6f5qa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appopenermdemof6f5qa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_1."
      delete_attempted=true
      services_found=true # A service was found and is being deleted
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_1. Retrying..."
      services_found=true # A service was found but deletion failed
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_1."
  fi

  # Check and delete service in APP_REGION_2
  if gcloud run services describe "appopenermdemof6f5qa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appopenermdemof6f5qa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_2."
      delete_attempted=true
      services_found=true # A service was found and is being deleted
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_2. Retrying..."
      services_found=true # A service was found but deletion failed
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_2."
  fi

  # If no services were found, exit the loop
  if ! $services_found; then
    echo "No Cloud Run services found. Exiting..."
    break
  fi

  # If services were found and attempted, increment attempt and retry
  attempt=$((attempt + 1))
  echo "Retrying... Attempt $attempt of $max_attempts."
  sleep 10
done


# Ensure application directory is empty
sudo mkdir -p /share/appopenermdemof6f5qa && sudo rm -rf /share/appopenermdemof6f5qa/* && sudo chown -R 1000:1000 /share/appopenermdemof6f5qa && sudo chmod 775 /share/appopenermdemof6f5qa

# Attempt to download the backup file only if BACKUP_FILEID is not empty
if [ -n "" ] ; then
    echo "Attempting to download the backup file using gdown..."
    echo "Using gdown from /root/.local/bin/gdown"
    
    # Try downloading with full path if needed
    if sudo /root/.local/bin/gdown  -O appopenermdemof6f5qa.zip; then
        echo "Backup file downloaded successfully"
        if [ -f appopenermdemof6f5qa.zip ]; then
            echo "Backup file exists and is $(du -h appopenermdemof6f5qa.zip | cut -f1) in size"
        fi
    else
        echo "Warning: Failed to download the backup file using /root/.local/bin/gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID is empty."
fi

# Check if the backup file exists locally
if [ -f "appopenermdemof6f5qa.zip" ]; then
    echo "Backup file exists locally."
    
    # Extract the backup file and set  permissions
    sudo mkdir -p appopenermdemof6f5qa && sudo rm -rf appopenermdemof6f5qa/* && sudo unzip appopenermdemof6f5qa.zip -d appopenermdemof6f5qa
    
    # Move directory
    sudo rm -rf /share/appopenermdemof6f5qa/* && sudo mv appopenermdemof6f5qa/* /share/appopenermdemof6f5qa/

    # Change ownership
    sudo chmod -R 0777 /share/appopenermdemof6f5qa && sudo chown -R 1000:1000 /share/appopenermdemof6f5qa

    # Set proper ownership
    sudo chown -R 1000:1000 /share/appopenermdemof6f5qa

    # 2. Secure base permissions
    sudo find /share/appopenermdemof6f5qa -type d -exec chmod 755 {} \;  # Directories
    sudo find /share/appopenermdemof6f5qa -type f -exec chmod 644 {} \;  # Files

    # Make specific directories writable by web server only
    sudo chmod -R 755 /share/appopenermdemof6f5qa/default/documents

    # Secure sensitive files
    sudo chmod 600 /share/appopenermdemof6f5qa/default/sqlconf.php  # DB config

    # Define the path to the sqlconf.php file
    SQLCONF_FILE="/share/appopenermdemof6f5qa/default/sqlconf.php"

    # Replace hardcoded values with environment variables
    sudo sed -i "s/\$host\s*=\s*'[^']*'/\$host = '172.21.0.3'/" "$SQLCONF_FILE"
    sudo sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF_FILE"
    sudo sed -i "s/\$login\s*=\s*'[^']*'/\$login = 'appopenermdemof6f5qa'/" "$SQLCONF_FILE"
    sudo sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = 'GCRApj6u7p6agSYd'/" "$SQLCONF_FILE"
    sudo sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = 'appopenermdemof6f5qa'/" "$SQLCONF_FILE"
    sudo sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = 'g%L9hkVajm3p@ApK';" "$SQLCONF_FILE"

    echo "sqlconf.php updated successfully!"

    # Delete Backup from bastion host
    sudo rm -rf appopenermdemof6f5qa.zip && sudo rm -rf appopenermdemof6f5qa
fi

# Check if the shared directory exists
if [ ! -d /share/appopenermdemof6f5qa ]; then echo 'Error: /share/appopenermdemof6f5qa does not exist.'; exit 1; fi

echo "Script completed successfully!"
