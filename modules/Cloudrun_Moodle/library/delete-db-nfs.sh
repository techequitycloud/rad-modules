#!/bin/bash
# set -x

# Copyright 2024 Tech Equity Ltd

# echo "Current working directory: $(pwd)"
# echo "Listing files in $(pwd):"
# ls -la

export PROJECT_ID=$1
export NFS_IP=$2
export NFS_ZONE=$3
export DB_BACKUP_BUCKET=$4
export DB_BACKUP_FILE=$5
export DB_IP=$6
export DB_NAME=$7
export DB_USER=$8
export DB_PASS=$9
export PG_PASS=${10}
export APP_NAME=${11}
export APP_REGIONS_STRING=${12}
export SERVICE_ACCOUNT=${13}

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

FLAG_FILE="./.db_script_ran_flag"

# Check if the script has run before by checking for the flag file
if [ ! -f "$FLAG_FILE" ]; then
    echo "First run detected. Waiting for 180 seconds."
    sleep 180
    # Create the flag file to indicate the script has run
    touch "$FLAG_FILE"
    for i in $(gcloud --project="${PROJECT_ID}" compute os-login ssh-keys list $SA_ARG 2>/dev/null | grep -v FINGERPRINT); do echo $i; gcloud --project="${PROJECT_ID}" compute os-login ssh-keys remove --key $i $SA_ARG 2>/dev/null; done # Avoid error "Login profile size exceeds 32 KiB"
else
    echo "Flag file exists. Skipping initial delay."
fi

# Maximum number of attempts
max_attempts=3
attempt=0

# Loop until the NFS VM instance is in RUNNING status or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  # Get the instance name using the internal IP address
  NFS_VM=$(gcloud --project $PROJECT_ID compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(NAME)" $SA_ARG)
  
  # Check the status of the instance
  status=$(gcloud --project $PROJECT_ID compute instances list --filter="INTERNAL_IP=${NFS_IP}" --format="value(status)" $SA_ARG)
  
  if [ "$status" = "RUNNING" ]; then
    echo "Instance is running."
    break
  else
    echo "Waiting for instance to be running... (Attempt $((attempt + 1)) of $max_attempts)"
    sleep 10 # wait before retrying
  fi
  
  attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
  echo "Max attempts reached. Instance is not running."
fi

APP_REGIONS_STRING=$(echo "$APP_REGIONS_STRING" | tr -d '[:space:]')
IFS=',' read -r -a APP_REGIONS <<< "$APP_REGIONS_STRING"

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false # Flag to track if any services were found

  for APP_REGION in "${APP_REGIONS[@]}"; do
    if gcloud run services describe ${APP_NAME} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; then
      echo "Cloud Run service still exists in region ${APP_REGION}. Attempting to delete..."
      
      # Try to delete the service
      if gcloud run services delete ${APP_NAME} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG; then
        echo "Cloud Run service is being deleted in region ${APP_REGION}."
        delete_attempted=true
        services_found=true # A service was found and is being deleted
      else
        echo "Failed to delete Cloud Run service in region ${APP_REGION}. Retrying..."
        services_found=true # A service was found but deletion failed
      fi
    else
      echo "Cloud Run service does not exist in region ${APP_REGION}."
    fi
  done

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

# Wait for 120 seconds if deletion was attempted
if $delete_attempted; then
  echo "Waiting for 120 seconds to allow connections to terminate..."
  sleep 120
fi

APP_REGION=$(echo $APP_REGIONS_STRING | cut -d',' -f1)

if [ "$delete_attempted" = false ]; then
  echo "Max attempts reached or service deletion failed."
fi

echo "Cloud Run service deleted or does not exist. Proceeding."

# Display database user
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${DB_PASS} && psql -U ${DB_USER} -h ${DB_IP} -d postgres -c '\l'"

# Set maximum retries to drop the database
max_retries=10
attempt_num=1

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    # Terminate all connections to the database
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD='${PG_PASS}' && psql -U 'postgres' -h '${DB_IP}' -d postgres -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\''${DB_NAME}'\'';'"

    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
    export PGPASSWORD=${PG_PASS} && 
    psql -U postgres -h ${DB_IP} -d postgres <<EOF
    DO \\$\\$
    BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
    END IF;
    END
    \\$\\$;
    GRANT ALL PRIVILEGES ON DATABASE postgres TO ${DB_USER};
    ALTER ROLE ${DB_USER} CREATEDB;
    ALTER ROLE ${DB_USER} INHERIT;
    GRANT postgres TO ${DB_USER};
EOF"

    # Check if the database exists
    db_check_result=$(gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${PG_PASS} && psql -U postgres -h ${DB_IP} -d postgres -c \"SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';\"")

    # Check the result and attempt to drop the database and role
    if echo "$db_check_result" | grep -q '1 row'; then        # Attempt to drop the database
        gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
        export PGPASSWORD=${DB_PASS} && 
        psql -U ${DB_USER} -h ${DB_IP} -d postgres <<EOF
        REASSIGN OWNED BY ${DB_USER} TO postgres;
        DROP OWNED BY ${DB_USER};
EOF"

        drop_database_result=$(gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${DB_PASS} && psql -U ${DB_USER} -h ${DB_IP} -d postgres -c 'DROP DATABASE IF EXISTS \"${DB_NAME}\";'")
    else
        echo "Database ${DB_NAME} does not exist."
        export drop_database_result="DATABASE DOES NOT EXIST"
    fi

    # Check if the drop was successful
    if echo "$drop_database_result" | grep -q 'DATABASE DOES NOT EXIST'; then
        echo "Database ${DB_NAME} does not exist."
        break 
    elif echo "$drop_database_result" | grep -q 'DROP DATABASE'; then
        echo "Database ${DB_NAME} dropped successfully."
        sleep 120 # to wait for connections to terminate
        break
    else
        echo "Failed to drop database ${DB_NAME}. Retrying in 10 seconds..."
        sleep 10
    fi

    ((attempt_num++))
done

# If we reached the maximum number of retries, print a message
if [ $attempt_num -gt $max_retries ]; then
  echo "Reached maximum number of retries. Failed to drop database ${DB_NAME}."
fi

# Drop the role
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
export PGPASSWORD=${DB_PASS}
psql -U ${DB_USER} -h ${DB_IP} -d postgres <<EOF
REASSIGN OWNED BY ${DB_USER} TO postgres;
DROP OWNED BY ${DB_USER};
EOF"

gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
export PGPASSWORD=${PG_PASS}
psql -U postgres -h ${DB_IP} -d postgres <<EOF
DROP ROLE IF EXISTS ${DB_USER};
EOF"

# Delete the application data directory
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf /share/${DB_USER}"