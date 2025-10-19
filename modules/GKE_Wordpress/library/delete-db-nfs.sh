#!/bin/bash
# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# set -x
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
export APP_REGION=${12}
export APP_NAMESPACE=${13}
export GCP_CLUSTER=${14}
export SERVICE_ACCOUNT=${15}

if [ -n "${SERVICE_ACCOUNT}" ] 
then
    SA_ARG="--impersonate-service-account=${SERVICE_ACCOUNT}"
fi

FLAG_FILE="./.db_script_ran_flag"

for key in $(gcloud --project $PROJECT_ID compute os-login ssh-keys list --format="value(KEY)"); do
  gcloud compute os-login ssh-keys remove --key "$key"
done

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

# Initialize a flag to determine if the delete operation was attempted
delete_attempted=false
max_attempts=5
attempt=0

gcloud container clusters get-credentials ${GCP_CLUSTER} --region ${APP_REGION} --project ${PROJECT_ID}

# Loop to check if the deployment exists and delete it
while kubectl get deployment ${APP_NAME} --namespace=${APP_NAMESPACE}; do
    echo "deployment ${APP_NAME} exists. Attempting to delete... (Attempt: $((attempt + 1)) of $max_attempts)"
    
    # If the deployment is still there, try to delete it
    if kubectl delete deployment ${APP_NAME} --namespace=${APP_NAMESPACE} --force; then
        echo "deployment ${APP_NAME} is being deleted."
        delete_attempted=true
        break
    else
        echo "Failed to delete deployment ${APP_NAME}. Retrying..."
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "Maximum delete attempts reached. Exiting..."
            break
        fi
        sleep 10
    fi
done

if [ "$delete_attempted" = true ]; then
    echo "Waiting for 120 seconds for the service to be completely deleted."
    sleep 120
fi

echo "Kubernetes service deleted or does not exist. Proceeding."

# Display database user
gcloud compute --project ${PROJECT_ID} --quiet ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="export PGPASSWORD=${DB_PASS} && psql -U ${DB_USER} -h ${DB_IP} -d postgres -c '\l'"

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
gcloud --project ${PROJECT_ID} --quiet compute ssh ${NFS_VM} --zone ${NFS_ZONE} $SA_ARG --command="sudo rm -rf /share/${DB_NAME}"