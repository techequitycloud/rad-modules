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
  services_found=false # Flag to track if any services were found

  # Check and delete service in APP_REGION_1
  if gcloud run services describe "appcyclosdemo166fqa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appcyclosdemo166fqa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_1" --quiet; then
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
  if gcloud run services describe "appcyclosdemo166fqa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" 2>/dev/null; then
    echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."
    
    # Try to delete the service
    if gcloud run services delete "appcyclosdemo166fqa" --project="qwiklabs-gcp-00-9c58e150e7c1" --region="$APP_REGION_2" --quiet; then
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
export PGPASSWORD=g%L9hkVajm3p@ApK && psql -U postgres -h 172.21.0.5 -d postgres -c '\l'

# Set maximum retries to drop the database
max_retries=5
attempt_num=1

# Function to check if database exists
check_database_exists() {
    local result=$(PGPASSWORD="g%L9hkVajm3p@ApK" psql -U postgres -h 172.21.0.5 -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = 'appcyclosdemo166fqa';" 2>/dev/null | tr -d ' \n')
    [[ "$result" == "1" ]]
}

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    echo "Terminating connections to database appcyclosdemo166fqa..."
    export PGPASSWORD='g%L9hkVajm3p@ApK'
    psql -U 'postgres' -h '172.21.0.5' -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'appcyclosdemo166fqa' AND pid <> pg_backend_pid();" 2>/dev/null

    echo "Creating/updating user role appcyclosdemo166fqa..."
    psql -U 'postgres' -h '172.21.0.5' -d postgres <<EOF
    DO \$\$
    BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'appcyclosdemo166fqa') THEN
        CREATE ROLE appcyclosdemo166fqa WITH LOGIN PASSWORD 'ig3TsED0mIIwiiEb';
        RAISE NOTICE 'Role appcyclosdemo166fqa created';
    ELSE
        ALTER ROLE appcyclosdemo166fqa WITH PASSWORD 'ig3TsED0mIIwiiEb';
        RAISE NOTICE 'Role appcyclosdemo166fqa password updated';
    END IF;
    END
    \$\$;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO appcyclosdemo166fqa;
    ALTER ROLE appcyclosdemo166fqa CREATEDB;
    ALTER ROLE appcyclosdemo166fqa INHERIT;
EOF

    echo "Creating extensions in appcyclosdemo166fqa..."
    psql -U 'postgres' -h '172.21.0.5' -d "appcyclosdemo166fqa" <<EOF
    CREATE EXTENSION IF NOT EXISTS cube;
    CREATE EXTENSION IF NOT EXISTS earthdistance;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS unaccent;
EOF

    # Check if the database exists using the function
    if check_database_exists; then
        echo "Database appcyclosdemo166fqa exists, attempting to drop it..."
        
        # Try to drop using database owner credentials first
        echo "Dropping database using owner credentials..."
        export PGPASSWORD='ig3TsED0mIIwiiEb'
        drop_result=$(psql -U 'appcyclosdemo166fqa' -h '172.21.0.5' -d postgres -c "DROP DATABASE IF EXISTS appcyclosdemo166fqa;" 2>&1)
        drop_exit_code=$?
        
        # Check if drop was successful
        if [ $drop_exit_code -eq 0 ] && ! check_database_exists; then
            echo "Database appcyclosdemo166fqa dropped successfully."
            break
        else
            echo "Failed to drop database with owner credentials. Error: $drop_result"
            
            # Try alternative approach - change ownership first
            echo "Trying to change database ownership to postgres..."
            export PGPASSWORD='g%L9hkVajm3p@ApK'
            psql -U 'postgres' -h '172.21.0.5' -d postgres -c "ALTER DATABASE appcyclosdemo166fqa OWNER TO postgres;" 2>/dev/null
            
            # Terminate connections again
            psql -U 'postgres' -h '172.21.0.5' -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'appcyclosdemo166fqa' AND pid <> pg_backend_pid();" 2>/dev/null
            
            # Try dropping as postgres
            echo "Attempting to drop as postgres user..."
            drop_result2=$(psql -U 'postgres' -h '172.21.0.5' -d postgres -c "DROP DATABASE IF EXISTS appcyclosdemo166fqa;" 2>&1)
            
            if [ $? -eq 0 ] && ! check_database_exists; then
                echo "Database appcyclosdemo166fqa dropped successfully."
                break
            else
                echo "Still failed to drop database. Error: $drop_result2"
            fi
        fi
    else
        echo "Database appcyclosdemo166fqa does not exist."
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
    echo "Reached maximum number of retries. Failed to drop database appcyclosdemo166fqa."
    echo "Database still exists - manual intervention required."
    exit 1
fi

# Create the database - only if it doesn't exist
echo "Creating database appcyclosdemo166fqa..."
export PGPASSWORD=ig3TsED0mIIwiiEb
if ! check_database_exists; then
    create_result=$(psql -U appcyclosdemo166fqa -h 172.21.0.5 -d postgres -c "CREATE DATABASE appcyclosdemo166fqa OWNER appcyclosdemo166fqa;" 2>&1)
    if [ $? -eq 0 ]; then
        echo "Database created successfully."
        
        export PGPASSWORD=g%L9hkVajm3p@ApK
        echo "Creating/updating user role appcyclosdemo166fqa..."
        psql -U 'postgres' -h '172.21.0.5' -d postgres <<EOF
        GRANT ALL PRIVILEGES ON DATABASE appcyclosdemo166fqa TO appcyclosdemo166fqa;
        ALTER ROLE appcyclosdemo166fqa CREATEDB;
        ALTER ROLE appcyclosdemo166fqa INHERIT;
EOF

        echo "Creating extensions in appcyclosdemo166fqa..."
        psql -U 'postgres' -h '172.21.0.5' -d "appcyclosdemo166fqa" <<EOF
        CREATE EXTENSION IF NOT EXISTS cube;
        CREATE EXTENSION IF NOT EXISTS earthdistance;
        CREATE EXTENSION IF NOT EXISTS postgis;
        CREATE EXTENSION IF NOT EXISTS unaccent;
EOF
    else
        echo "Failed to create database: $create_result"
        exit 1
    fi
else
    echo "Database already exists, skipping creation."
fi

# Attempt to download the backup file only if BACKUP_FILEID is not empty
if [ -n "" ] ; then
    echo "Attempting to download the backup file using gdown..."
    echo "Using gdown from /root/.local/bin/gdown"
    
    # Try downloading with full path if needed
    if sudo /root/.local/bin/gdown  -O appcyclosdemo166fqa.zip; then
        echo "Backup file downloaded successfully"
        if [ -f appcyclosdemo166fqa.zip ]; then
            echo "Backup file exists and is $(du -h appcyclosdemo166fqa.zip | cut -f1) in size"
        fi
    else
        echo "Warning: Failed to download the backup file using /root/.local/bin/gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID is empty."
fi

if [ -f "appcyclosdemo166fqa.zip" ]; then
    # Extract the backup file 
    sudo mkdir -p appcyclosdemo166fqa && sudo rm -rf appcyclosdemo166fqa/* && sudo unzip appcyclosdemo166fqa.zip -d appcyclosdemo166fqa

    # Restore the database
    echo "Restoring database from backup..."
    export PGPASSWORD=ig3TsED0mIIwiiEb
    restore_result=$(psql "host=172.21.0.5 port=5432 sslmode=disable dbname=appcyclosdemo166fqa user=appcyclosdemo166fqa" < appcyclosdemo166fqa/dump.sql 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "Database restored successfully."
    else
        echo "Failed to restore database: $restore_result"
        exit 1
    fi

    # Delete Backup from bastion host
    sudo rm -rf appcyclosdemo166fqa/dump.sql && rm -rf appcyclosdemo166fqa.zip
fi

echo "Script completed successfully!"

