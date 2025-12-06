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
  if gcloud run services describe "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    if gcloud run services delete "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_1" --quiet; then
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
  if gcloud run services describe "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    if gcloud run services delete "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_2" --quiet; then
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
  if gcloud run services describe "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    if gcloud run services delete "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_1" --quiet; then
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
  if gcloud run services describe "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    if gcloud run services delete "appwpdemof367qa" --project="qwiklabs-gcp-02-9f7942837ab3" --region="$APP_REGION_2" --quiet; then
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
rm -rf ~/.my.cnf
cat > ~/.my.cnf << 'EOF'
[client]
user=root
password=k0b40z%fC_y4HLB@
host=10.230.0.3
EOF
chmod 600 ~/.my.cnf

# To authorize remote connection from root user
# mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';"

echo "Displaying databases..."
mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e 'SHOW DATABASES;'

# Set maximum retries to drop the database
max_retries=5
attempt_num=1

# Function to check if database exists
check_database_exists() {
    local result=$(mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'appwpdemof367qa';" 2>/dev/null | grep -c "appwpdemof367qa")
    [[ "$result" == "1" ]]
}

# Create/update user with NO global privileges initially
echo "Creating/updating user appwpdemof367qa..."
mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" <<EOF
CREATE USER IF NOT EXISTS 'appwpdemof367qa'@'%' IDENTIFIED BY 'os0%z1Q@FDVAliL0';
ALTER USER 'appwpdemof367qa'@'%' IDENTIFIED BY 'os0%z1Q@FDVAliL0';
# -- ✅ Remove any existing global privileges
# REVOKE ALL PRIVILEGES ON *.* FROM 'appwpdemof367qa'@'%';
FLUSH PRIVILEGES;
EOF

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    echo "Terminating connections to database appwpdemof367qa..."
    # Fixed connection termination logic
    kill_statements=$(mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "SELECT CONCAT('KILL ', id, ';') FROM INFORMATION_SCHEMA.PROCESSLIST WHERE db = 'appwpdemof367qa' AND id != CONNECTION_ID();" -N -s 2>/dev/null)
    if [ -n "$kill_statements" ]; then
        echo "$kill_statements" | mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" 2>/dev/null
    fi

    if check_database_exists; then
        echo "Database appwpdemof367qa exists, attempting to drop it..."
        
        # Try to drop as root user (DB_USER may not have drop privileges yet)
        echo "Dropping database as root user..."
        drop_result=$(mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "DROP DATABASE IF EXISTS \`appwpdemof367qa\`;" 2>&1)
        
        if [ $? -eq 0 ] && ! check_database_exists; then
            echo "Database appwpdemof367qa dropped successfully."
            break
        else
            echo "Failed to drop database. Error: $drop_result"
        fi
    else
        echo "Database appwpdemof367qa does not exist."
        break
    fi

    ((attempt_num++))
    
    if [ $attempt_num -le $max_retries ]; then
        echo "Waiting 10 seconds before next attempt..."
        sleep 10
    fi
done

if [ $attempt_num -gt $max_retries ]; then
    echo "Reached maximum number of retries. Failed to drop database appwpdemof367qa."
    echo "Database still exists - manual intervention required."
    exit 1
fi

# Create the database as root
echo "Creating database appwpdemof367qa..."
if ! check_database_exists; then
    create_result=$(mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "CREATE DATABASE \`appwpdemof367qa\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1)
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
echo "Granting privileges to appwpdemof367qa ONLY on database appwpdemof367qa..."
mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" <<EOF
-- Grant all privileges on the specific database only
GRANT ALL PRIVILEGES ON \`appwpdemof367qa\`.* TO 'appwpdemof367qa'@'%';
-- Allow user to grant privileges on this database to others (if needed)
GRANT GRANT OPTION ON \`appwpdemof367qa\`.* TO 'appwpdemof367qa'@'%';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo "Privileges granted successfully on database appwpdemof367qa only."
else
    echo "Failed to grant privileges on database appwpdemof367qa."
    exit 1
fi

# Verify user has access only to the intended database
echo "Verifying user privileges..."
mysql --defaults-file=~/.my.cnf -u root -h "10.230.0.3" -e "SHOW GRANTS FOR 'appwpdemof367qa'@'%';"

# Attempt to download the backup file only if BACKUP_FILEID is not empty
if [ -n "" ] ; then
    echo "Attempting to download the backup file using gdown..."
    echo "Using gdown from /root/.local/bin/gdown"
    
    if sudo /root/.local/bin/gdown "" -O "appwpdemof367qa.zip"; then
        echo "Backup file downloaded successfully"
        if [ -f "appwpdemof367qa.zip" ]; then
            echo "Backup file exists and is $(du -h "appwpdemof367qa.zip" | cut -f1) in size"
        fi
    else
        echo "Warning: Failed to download the backup file using /root/.local/bin/gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID is empty."
fi

if [ -f "appwpdemof367qa.zip" ]; then
    # Extract the backup file using a safe directory name
    sudo mkdir -p "appwpdemof367qa" && sudo rm -rf "appwpdemof367qa"/* && sudo unzip "appwpdemof367qa.zip" -d "appwpdemof367qa"

    # Restore the database using DB_USER (who now has privileges on this database only)
    echo "Restoring database from backup..."

    # Create MySQL configuration file
    rm -rf ~/.my.cnf
    cat > ~/.my.cnf << 'EOF'
    [client]
    user=appwpdemof367qa
    password=os0%z1Q@FDVAliL0
    host=10.230.0.3
EOF
    chmod 600 ~/.my.cnf

    restore_result=$(mysql --defaults-file=~/.my.cnf -u "appwpdemof367qa" -h "10.230.0.3" "appwpdemof367qa" < "appwpdemof367qa/dump.sql" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "Database restored successfully."
    else
        echo "Failed to restore database: $restore_result"
        exit 1
    fi

    # Delete Backup from bastion host
    sudo rm -rf "appwpdemof367qa" && rm -rf "appwpdemof367qa.zip"
fi

# Clean up 
unset MYSQL_PWD
rm -rf $HOME/.my.cnf

echo "Script completed successfully!"

