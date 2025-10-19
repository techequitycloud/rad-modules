#!/bin/bash
set -x

# Copyright 2024 Tech Equity Ltd

echo "Current working directory: $(pwd)"
echo "Listing files in $(pwd):"
ls -la

export PROJECT_ID=$1
export NFS_IP=$2
export NFS_ZONE=$3
export BACKUP_BUCKET=$4
export BACKUP_FILEID=$5
export BACKUP_FILE=$6
export DB_IP=$7
export DB_NAME=$8
export DB_USER=$9
export DB_PASS=${10}
export PG_PASS=${11}
export APP_NAME=${12}
export APP_REGIONS_STRING=${13}
export ASSET_BUCKET=${14}
export SERVICE_ACCOUNT=${15}

if [ -n "${SERVICE_ACCOUNT}" ]; then
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

# Loop until the service no longer exists or max attempts reached
MAX_RETRIES=3
for APP_REGION in "${APP_REGIONS[@]}"; do
    RETRY_COUNT=0
    while true; do
        if gcloud run services describe ${APP_NAME} --project=${PROJECT_ID} --region=${APP_REGION} $SA_ARG 2>/dev/null; then
            echo "Cloud Run service still exists in region $APP_REGION. Attempting to delete..."
            
            if gcloud run services delete ${APP_NAME} --project=${PROJECT_ID} --region=${APP_REGION} --quiet $SA_ARG; then
                echo "Cloud Run service in region $APP_REGION is being deleted."
                sleep 120
                break
            else
                echo "Failed to delete Cloud Run service in region $APP_REGION. Retrying..."
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                    echo "Reached max retries for region $APP_REGION. Skipping..."
                    break
                fi
                sleep 10
            fi
        else
            echo "Cloud Run service does not exist in region $APP_REGION."
            break
        fi
    done
done

APP_REGION=$(echo $APP_REGIONS_STRING | cut -d',' -f1)

# Ensure application directory is empty
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo mkdir -p /share/${DB_USER} && sudo rm -rf /share/${DB_USER}/* && sudo chown -R nobody:nogroup /share/${DB_USER} && sudo chmod 775 /share/${DB_USER}"

# Install gdown 
pip3 install --upgrade gdown --user || pip install --upgrade gdown --user
export PATH="$HOME/.local/bin:$PATH"

# Attempt to download the backup file only if BACKUP_FILEID and BACKUP_FILE are not empty
if [ -n "${BACKUP_FILEID}" ] && [ -n "${BACKUP_FILE}" ]; then
    echo "Attempting to download the backup file using gdown..."
    gdown --id "${BACKUP_FILEID}" -O "${BACKUP_FILE}"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to download the backup file using gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID or BACKUP_FILE is empty."
fi

# Check if the backup file exists locally
if [ -f "${BACKUP_FILE}" ]; then
    echo "Backup file exists locally."

    # Copy the data backup file to NFS VM
    gcloud compute scp --project "${PROJECT_ID}" --zone "${NFS_ZONE}" "${BACKUP_FILE}" ${NFS_VM}:~/${BACKUP_FILE} $SA_ARG

    # Copy the data backup file to storage bucket
    gcloud compute --project "${PROJECT_ID}" --quiet ssh "${NFS_VM}" --zone "${NFS_ZONE}" $SA_ARG --command="gsutil cp ${BACKUP_FILE} gs://${ASSET_BUCKET}/${DB_NAME}_${BACKUP_FILE}"
else
    echo "Backup file does not exist locally. Checking GCS bucket."

    # Check if the file exists in the GCS bucket
    if gcloud --project $PROJECT_ID storage objects list "gs://${ASSET_BUCKET}" --format="value(name)" | grep -q "^${BACKUP_FILE}$"; then
        echo "Backup file found in GCS bucket. Downloading..."

        # Fallback: Copy the backup file from the GCS bucket
        gcloud --project $PROJECT_ID storage cp gs://${ASSET_BUCKET}/${BACKUP_FILE} $BACKUP_FILE --quiet $SA_ARG

        # Check again if the fallback download succeeded
        if [ -f "${BACKUP_FILE}" ]; then
            echo "Backup file successfully downloaded from GCS bucket."

            # Copy the data backup file to NFS VM
            gcloud compute scp --project "${PROJECT_ID}" --zone "${NFS_ZONE}" "${BACKUP_FILE}" ${NFS_VM}:~/${BACKUP_FILE} $SA_ARG

            # Copy the data backup file to storage bucket
            gcloud compute --project "${PROJECT_ID}" --quiet ssh "${NFS_VM}" --zone "${NFS_ZONE}" $SA_ARG --command="gsutil cp ${BACKUP_FILE} gs://${ASSET_BUCKET}/${DB_NAME}_${BACKUP_FILE}"
        else
            echo "Database backup file is either empty or does not exist after all attempts."
        fi
    else
        echo "Backup file does not exist in the GCS bucket."
    fi
fi

APP_REGION=$(echo $APP_REGIONS_STRING | cut -d',' -f1)

# Ensure application directory is empty
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo mkdir -p /share/${DB_USER} && sudo rm -rf /share/${DB_USER}/* && sudo chown -R nobody:nogroup /share/${DB_USER} && sudo chmod 775 /share/${DB_USER}"

# Install gdown 
pip3 install --upgrade gdown --user || pip install --upgrade gdown --user
export PATH="$HOME/.local/bin:$PATH"

# Attempt to download the backup file only if BACKUP_FILEID and BACKUP_FILE are not empty
if [ -n "${BACKUP_FILEID}" ] && [ -n "${BACKUP_FILE}" ]; then
    echo "Attempting to download the backup file using gdown..."
    gdown --id "${BACKUP_FILEID}" -O "${BACKUP_FILE}"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to download the backup file using gdown."
    fi
else
    echo "Skipping download as BACKUP_FILEID or BACKUP_FILE is empty."
fi

# Check if the backup file exists locally
if [ -f "${BACKUP_FILE}" ]; then
    echo "Backup file exists locally."

    # Copy the data backup file to NFS VM
    gcloud compute scp --project "${PROJECT_ID}" --zone "${NFS_ZONE}" "${BACKUP_FILE}" ${NFS_VM}:~/${BACKUP_FILE} $SA_ARG

    # Copy the data backup file to storage bucket
    gcloud compute --project "${PROJECT_ID}" --quiet ssh "${NFS_VM}" --zone "${NFS_ZONE}" $SA_ARG --command="gsutil cp ${BACKUP_FILE} gs://${ASSET_BUCKET}/${DB_NAME}_${BACKUP_FILE}"
else
    echo "Backup file does not exist locally. Checking GCS bucket."

    # Check if the file exists in the GCS bucket
    if gcloud --project $PROJECT_ID storage objects list "gs://${ASSET_BUCKET}" --format="value(name)" | grep -q "^${BACKUP_FILE}$"; then
        echo "Backup file found in GCS bucket. Downloading..."

        # Fallback: Copy the backup file from the GCS bucket
        gcloud --project $PROJECT_ID storage cp gs://${ASSET_BUCKET}/${BACKUP_FILE} $BACKUP_FILE --quiet $SA_ARG

        # Check again if the fallback download succeeded
        if [ -f "${BACKUP_FILE}" ]; then
            echo "Backup file successfully downloaded from GCS bucket."

            # Copy the data backup file to NFS VM
            gcloud compute scp --project "${PROJECT_ID}" --zone "${NFS_ZONE}" "${BACKUP_FILE}" ${NFS_VM}:~/${BACKUP_FILE} $SA_ARG

            # Copy the data backup file to storage bucket
            gcloud compute --project "${PROJECT_ID}" --quiet ssh "${NFS_VM}" --zone "${NFS_ZONE}" $SA_ARG --command="gsutil cp ${BACKUP_FILE} gs://${ASSET_BUCKET}/${DB_NAME}_${BACKUP_FILE}"
        else
            echo "Database backup file is either empty or does not exist after all attempts."
        fi
    else
        echo "Backup file does not exist in the GCS bucket."
    fi
fi

# Display database user
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${PG_PASS} && psql -U postgres -h ${DB_IP} -d postgres -c '\l'"

# Set maximum retries to drop the database
max_retries=5
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
    ELSE
        ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
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

        drop_database_result=$(gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
        export PGPASSWORD=${DB_PASS} && 
        psql -U ${DB_USER} -h ${DB_IP} -d postgres <<EOF
        DROP DATABASE IF EXISTS ${DB_NAME};
EOF")

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

if [ -n "${BACKUP_FILE}" ] && [ -f "${BACKUP_FILE}" ]; then
    
    # Extract the backup file and set  permissions
    gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo mkdir -p ${DB_NAME} && sudo rm -rf ${DB_NAME}/* && sudo unzip ${BACKUP_FILE} -d ${DB_NAME} && sudo mv ${DB_NAME}/filestore ${DB_NAME}/temp && sudo mkdir -p ${DB_NAME}/filestore && sudo mv ${DB_NAME}/temp ${DB_NAME}/filestore/${DB_NAME}"

    # Update the application URL
    gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sed -i -E 's|https://[^ ]+\.run\.app|${APP_URL}|g' /share/${DB_NAME}/dump.sql"
    
    # Move directory
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf /share/${DB_USER}/* && sudo mv ${DB_NAME}/* /share/${DB_USER}/"

    # Change ownership
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo chmod -R 0777 /share/${DB_USER} && sudo chown -R www-data:www-data /share/${DB_USER}"

    # Delete Backup from bastion host
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf ${BACKUP_FILE} && sudo rm -rf ${DB_NAME}"
fi

# Check if the shared directory exists
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="if [ ! -d /share/${DB_USER} ]; then echo 'Error: /share/${DB_USER} does not exist.'; exit 1; fi"

# Create the database
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="
export PGPASSWORD=${DB_PASS} && psql -U ${DB_USER} -h ${DB_IP} -d postgres <<EOF
     CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF"

# Check if the database creation was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create database ${DB_NAME}."
    exit 1
fi

if [ -n "${BACKUP_FILE}" ] && [ -f "${BACKUP_FILE}" ]; then
    
    # Restore the database
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${DB_PASS} && psql \"host=${DB_IP} port=5432 sslmode=disable dbname=${DB_NAME} user=${DB_USER}\" < /share/${DB_USER}/dump.sql"

    # Delete Backup from bastion host
    gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf /share/${DB_USER}/dump.sql"
fi

rm -rf  $BACKUP_FILE