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
APP_REGION_1=$(echo "${APP_REGION_1}" | tr -d '[:space:]')
APP_REGION_2=$(echo "${APP_REGION_2}" | tr -d '[:space:]')

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false # Flag to track if any services were found

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" --quiet; then
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
  if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" --quiet; then
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

# Display databases
export PGPASSWORD=${PG_PASS} && psql -U postgres -h ${DB_IP} -d postgres -c '\l'

# Set maximum retries to drop the database
max_retries=5
attempt_num=1

# Function to check if database exists
check_database_exists() {
    local result=$(PGPASSWORD="${PG_PASS}" psql -U postgres -h ${DB_IP} -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';" 2>/dev/null | tr -d ' \n')
    [[ "$result" == "1" ]]
}

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    echo "Terminating connections to database ${DB_NAME}..."
    export PGPASSWORD='${PG_PASS}'
    psql -U 'postgres' -h '${DB_IP}' -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" 2>/dev/null

    echo "Creating/updating user role ${DB_USER}..."
    psql -U 'postgres' -h '${DB_IP}' -d postgres <<EOF
    DO \$\$
    BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
        RAISE NOTICE 'Role ${DB_USER} created';
    ELSE
        ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
        RAISE NOTICE 'Role ${DB_USER} password updated';
    END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO ${DB_USER};
    ALTER ROLE ${DB_USER} CREATEDB;
    ALTER ROLE ${DB_USER} INHERIT;
EOF

    # Check if the database exists using the function
    if check_database_exists; then
        echo "Database ${DB_NAME} exists, attempting to drop it..."
        
        # Try to drop using database owner credentials first
        echo "Dropping database using owner credentials..."
        export PGPASSWORD='${DB_PASS}'
        drop_result=$(psql -U '${DB_USER}' -h '${DB_IP}' -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>&1)
        drop_exit_code=$?
        
        # Check if drop was successful
        if [ $drop_exit_code -eq 0 ] && ! check_database_exists; then
            echo "Database ${DB_NAME} dropped successfully."
            break
        else
            echo "Failed to drop database with owner credentials. Error: $drop_result"
            
            # Try alternative approach - change ownership first
            echo "Trying to change database ownership to postgres..."
            export PGPASSWORD='${PG_PASS}'
            psql -U 'postgres' -h '${DB_IP}' -d postgres -c "ALTER DATABASE ${DB_NAME} OWNER TO postgres;" 2>/dev/null
            
            # Terminate connections again
            psql -U 'postgres' -h '${DB_IP}' -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" 2>/dev/null
            
            # Try dropping as postgres
            echo "Attempting to drop as postgres user..."
            drop_result2=$(psql -U 'postgres' -h '${DB_IP}' -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>&1)
            
            if [ $? -eq 0 ] && ! check_database_exists; then
                echo "Database ${DB_NAME} dropped successfully."
                break
            else
                echo "Still failed to drop database. Error: $drop_result2"
            fi
        fi
    else
        echo "Database ${DB_NAME} does not exist."
        break
    fi

    # Increment the attempt number
    ((attempt_num++))
    
    # Wait before the next attempt
    if [ $attempt_num -le $max_retries ]; then
        echo "Waiting 10 seconds before next attempt..."
        sleep 10
    fi
done

# Check if we failed to drop the database
if [ $attempt_num -gt $max_retries ]; then
    echo "Reached maximum number of retries. Failed to drop database ${DB_NAME}."
    echo "Database still exists - manual intervention required."
    exit 1
fi

# Create the database - only if it doesn't exist
echo "Creating database ${DB_NAME}..."
export PGPASSWORD=${DB_PASS}
if ! check_database_exists; then
    create_result=$(psql -U ${DB_USER} -h ${DB_IP} -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>&1)
    if [ $? -eq 0 ]; then
        echo "Database created successfully."
        
        export PGPASSWORD=${PG_PASS}
        echo "Creating/updating user role ${DB_USER}..."
        psql -U 'postgres' -h '${DB_IP}' -d postgres <<EOF
        GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
        ALTER ROLE ${DB_USER} CREATEDB;
        ALTER ROLE ${DB_USER} INHERIT;
EOF
    else
        echo "Failed to create database: $create_result"
        exit 1
    fi
else
    echo "Database already exists, skipping creation."
fi

# Attempt to download the backup file only if BACKUP_FILEID is not empty
if [ -n "${BACKUP_FILEID}" ] ; then
    echo "Attempting to download the backup file using gdown..."
    echo "Using gdown from /root/.local/bin/gdown"
    
    # Try downloading with full path if needed
    if sudo /root/.local/bin/gdown ${BACKUP_FILEID} -O ${DB_NAME}.zip; then
        echo "Backup file downloaded successfully"
        if [ -f ${DB_NAME}.zip ]; then
            echo "Backup file exists and is $(du -h ${DB_NAME}.zip | cut -f1) in size"
        fi
    else
        echo "Warning: Failed to download the backup file using /root/.local/bin/gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID is empty."
fi

if [ -f "${DB_NAME}.zip" ]; then
    # Extract the backup file 
    sudo mkdir -p ${DB_USER} && sudo rm -rf ${DB_USER}/* && sudo unzip ${DB_NAME}.zip -d ${DB_USER}

    # Restore the database
    echo "Restoring database from backup..."
    export PGPASSWORD=${DB_PASS}
    restore_result=$(psql "host=${DB_IP} port=5432 sslmode=disable dbname=${DB_NAME} user=${DB_USER}" < ${DB_USER}/dump.sql 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "Database restored successfully."
    else
        echo "Failed to restore database: $restore_result"
        exit 1
    fi

    # Delete Backup from bastion host
    sudo rm -rf ${DB_USER}/dump.sql && rm -rf ${DB_NAME}.zip
fi

# Check if the database exists
echo "Checking if database ${DB_NAME} exists..."
database_exists=$(PGPASSWORD="${PG_PASS}" psql -U postgres -h "${DB_IP}" -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';" 2>/dev/null | tr -d ' \n')

if [ "$database_exists" == "1" ]; then
    echo "Database ${DB_NAME} exists."
else
    echo "Error: Database ${DB_NAME} does not exist."
    exit 1
fi

# Check if the database user exists
echo "Checking if database user ${DB_USER} exists..."
user_exists=$(PGPASSWORD="${PG_PASS}" psql -U postgres -h "${DB_IP}" -d postgres -t -c "SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}';" 2>/dev/null | tr -d ' \n')

if [ "$user_exists" == "1" ]; then
    echo "Database user ${DB_USER} exists."
else
    echo "Error: Database user ${DB_USER} does not exist."
    exit 1
fi

echo "Script completed successfully!"
