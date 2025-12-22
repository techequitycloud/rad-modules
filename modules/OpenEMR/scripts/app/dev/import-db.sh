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

# set -x

# Remove spaces from the region variables
APP_REGION_1=$(echo "us-central1" | tr -d '[:space:]')
APP_REGION_2=$(echo "" | tr -d '[:space:]')

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_1."
      delete_attempted=true
      services_found=true
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_1. Retrying..."
      services_found=true
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_1."
  fi

  # Check and delete service in APP_REGION_2
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_2."
      delete_attempted=true
      services_found=true
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_2. Retrying..."
      services_found=true
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_2."
  fi

  if ! $services_found; then
    echo "No Cloud Run services found. Exiting..."
    break
  fi

  attempt=$((attempt + 1))
  echo "Retrying... Attempt $attempt of $max_attempts."
  sleep 10
done

# set -x

# Remove spaces from the region variables
APP_REGION_1=$(echo "us-central1" | tr -d '[:space:]')
APP_REGION_2=$(echo "" | tr -d '[:space:]')

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_1."
      delete_attempted=true
      services_found=true
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_1. Retrying..."
      services_found=true
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_1."
  fi

  # Check and delete service in APP_REGION_2
  if gcloud run services describe "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    if gcloud run services delete "appopenermdemo9f10dev" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" --quiet; then
      echo "Cloud Run service is being deleted in region $APP_REGION_2."
      delete_attempted=true
      services_found=true
    else
      echo "Failed to delete Cloud Run service in region $APP_REGION_2. Retrying..."
      services_found=true
    fi
  else
    echo "Cloud Run service does not exist in region $APP_REGION_2."
  fi

  if ! $services_found; then
    echo "No Cloud Run services found. Exiting..."
    break
  fi

  attempt=$((attempt + 1))
  echo "Retrying... Attempt $attempt of $max_attempts."
  sleep 10
done

# Create MySQL configuration file
rm -rf $HOME/.my.cnf
cat > $HOME/.my.cnf << 'EOF'
[client]
user=root
password=g%L9hkVajm3p@ApK
host=172.21.0.3
EOF
chmod 600 $HOME/.my.cnf

# To authorize remote connection from root user
# mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';"

echo "Displaying databases..."
mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e 'SHOW DATABASES;'

# Set maximum retries to drop the database
max_retries=5
attempt_num=1

# Function to check if database exists
check_database_exists() {
    local result=$(mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'appopenermdemo9f10dev';" 2>/dev/null | grep -c "appopenermdemo9f10dev")
    [[ "$result" == "1" ]]
}

# Create/update user with NO global privileges initially
echo "Creating/updating user appopenermdemo9f10dev..."
mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" <<EOF
CREATE USER IF NOT EXISTS 'appopenermdemo9f10dev'@'%' IDENTIFIED BY 'GVyJqL%hRf6EuTf1';
ALTER USER 'appopenermdemo9f10dev'@'%' IDENTIFIED BY 'GVyJqL%hRf6EuTf1';
# -- ✅ Remove any existing global privileges
# REVOKE ALL PRIVILEGES ON *.* FROM 'appopenermdemo9f10dev'@'%';
FLUSH PRIVILEGES;
EOF

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    echo "Terminating connections to database appopenermdemo9f10dev..."
    # Fixed connection termination logic
    kill_statements=$(mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "SELECT CONCAT('KILL ', id, ';') FROM INFORMATION_SCHEMA.PROCESSLIST WHERE db = 'appopenermdemo9f10dev' AND id != CONNECTION_ID();" -N -s 2>/dev/null)
    if [ -n "$kill_statements" ]; then
        echo "$kill_statements" | mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" 2>/dev/null
    fi

    if check_database_exists; then
        echo "Database appopenermdemo9f10dev exists, attempting to drop it..."
        
        # Try to drop as root user (DB_USER may not have drop privileges yet)
        echo "Dropping database as root user..."
        drop_result=$(mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "DROP DATABASE IF EXISTS \`appopenermdemo9f10dev\`;" 2>&1)
        
        if [ $? -eq 0 ] && ! check_database_exists; then
            echo "Database appopenermdemo9f10dev dropped successfully."
            break
        else
            echo "Failed to drop database. Error: $drop_result"
        fi
    else
        echo "Database appopenermdemo9f10dev does not exist."
        break
    fi

    ((attempt_num++))
    
    if [ $attempt_num -le $max_retries ]; then
        echo "Waiting 10 seconds before next attempt..."
        sleep 10
    fi
done

if [ $attempt_num -gt $max_retries ]; then
    echo "Reached maximum number of retries. Failed to drop database appopenermdemo9f10dev."
    echo "Database still exists - manual intervention required."
    exit 1
fi

# Create the database as root
echo "Creating database appopenermdemo9f10dev..."
if ! check_database_exists; then
    create_result=$(mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "CREATE DATABASE \`appopenermdemo9f10dev\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1)
    if [ $? -eq 0 ]; then
        echo "Database created successfully."
    else
        echo "Failed to create database: $create_result"
        exit 1
    fi
else
    echo "Database already exists, skipping creation."
fi

# ✅ Grant privileges ONLY on the specific database
echo "Granting privileges to appopenermdemo9f10dev ONLY on database appopenermdemo9f10dev..."
mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" <<EOF
-- Grant all privileges on the specific database only
GRANT ALL PRIVILEGES ON \`appopenermdemo9f10dev\`.* TO 'appopenermdemo9f10dev'@'%';
-- Allow user to grant privileges on this database to others (if needed)
GRANT GRANT OPTION ON \`appopenermdemo9f10dev\`.* TO 'appopenermdemo9f10dev'@'%';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "Privileges granted successfully on database appopenermdemo9f10dev only."
else
    echo "Failed to grant privileges on database appopenermdemo9f10dev."
    exit 1
fi

# Verify user has access only to the intended database
echo "Verifying user privileges..."
mysql --defaults-file=$HOME/.my.cnf -u root -h "172.21.0.3" -e "SHOW GRANTS FOR 'appopenermdemo9f10dev'@'%';"

# Clean up 
unset MYSQL_PWD
rm -rf $HOME/.my.cnf

echo "Script completed successfully!"
