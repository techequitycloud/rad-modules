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
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" --quiet; then
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
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" --quiet; then
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


# Ensure application directory is empty and created
sudo mkdir -p /share/appopenermdemo9f10dev && sudo rm -rf /share/appopenermdemo9f10dev/* && sudo chown -R 1000:1000 /share/appopenermdemo9f10dev && sudo chmod 775 /share/appopenermdemo9f10dev

# Create default directory
sudo mkdir -p /share/appopenermdemo9f10dev/default

# Create sqlconf.php
cat <<EOF | sudo tee /share/appopenermdemo9f10dev/default/sqlconf.php > /dev/null
<?php
//  OpenEMR
//  MySQL Config

global \$disable_utf8_flag;
\$disable_utf8_flag = false;

\$host   = '172.21.0.3';
\$port   = '3306';
\$login  = 'appopenermdemo9f10dev';
\$pass   = 'GVyJqL%hRf6EuTf1';
\$dbase  = 'appopenermdemo9f10dev';
\$db_encoding = 'utf8mb4';

\$sqlconf = [];
global \$sqlconf;
\$sqlconf["host"]= \$host;
\$sqlconf["port"] = \$port;
\$sqlconf["login"] = \$login;
\$sqlconf["pass"] = \$pass;
\$sqlconf["dbase"] = \$dbase;
\$sqlconf["db_encoding"] = \$db_encoding;
\$rootpass = 'g%L9hkVajm3p@ApK';

//////////////////////////
//////////////////////////
//////////////////////////
//////DO NOT TOUCH THIS///
\$config = 0; /////////////
//////////////////////////
//////////////////////////
//////////////////////////
EOF

# Set permissions
sudo chown -R 1000:1000 /share/appopenermdemo9f10dev
sudo chmod 755 /share/appopenermdemo9f10dev/default/sqlconf.php

# Create other necessary directories (documents, images, etc.) to ensure they are writable
sudo mkdir -p /share/appopenermdemo9f10dev/default/documents
sudo mkdir -p /share/appopenermdemo9f10dev/default/edi
sudo mkdir -p /share/appopenermdemo9f10dev/default/era
sudo mkdir -p /share/appopenermdemo9f10dev/default/letter_templates
sudo mkdir -p /share/appopenermdemo9f10dev/default/images
sudo chown -R 1000:1000 /share/appopenermdemo9f10dev
sudo chmod -R 775 /share/appopenermdemo9f10dev

# Check if the shared directory exists
if [ ! -d /share/appopenermdemo9f10dev ]; then echo 'Error: /share/appopenermdemo9f10dev does not exist.'; exit 1; fi

echo "Script completed successfully!"
