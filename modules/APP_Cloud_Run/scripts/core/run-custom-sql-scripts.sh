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

#########################################################################
# Run Custom SQL Scripts for Database Initialization
#########################################################################

set -e

# Required environment variables:
# - SQL_SCRIPTS_BUCKET: GCS bucket containing SQL scripts (without gs:// prefix)
# - SQL_SCRIPTS_PATH: Path prefix in bucket (e.g., "scripts/init/")
# - DB_TYPE: Database type (MYSQL, POSTGRES, SQLSERVER)
# - DB_HOST: Database host
# - DB_PORT: Database port
# - DB_NAME: Database name
# - DB_USER: Database username (for regular scripts)
# - DB_PASSWORD: Database password
# - ROOT_USER: Database root username (for privileged scripts)
# - ROOT_PASSWORD: Database root password
# - USE_ROOT: "true" to execute scripts as root user

echo "=== Custom SQL Scripts Initialization Job ==="
echo "Scripts Bucket: gs://${SQL_SCRIPTS_BUCKET}"
echo "Scripts Path: ${SQL_SCRIPTS_PATH}"
echo "Database Type: ${DB_TYPE}"
echo "Database: ${DB_NAME}"
echo "Use Root User: ${USE_ROOT:-false}"

# Install required packages
echo "Installing required packages..."
if [ "$DB_TYPE" = "MYSQL" ]; then
    apt-get update -qq && apt-get install -y -qq default-mysql-client
elif [ "$DB_TYPE" = "POSTGRES" ]; then
    apt-get update -qq && apt-get install -y -qq postgresql-client
elif [ "$DB_TYPE" = "SQLSERVER" ]; then
    echo "SQL Server custom scripts not yet implemented"
    exit 1
else
    echo "Unknown database type: ${DB_TYPE}"
    exit 1
fi

# Create temporary directory for scripts
SCRIPTS_DIR="/tmp/sql_scripts"
mkdir -p "${SCRIPTS_DIR}"

# Download SQL scripts from GCS
echo "Downloading SQL scripts from GCS..."
GCS_URI="gs://${SQL_SCRIPTS_BUCKET}/${SQL_SCRIPTS_PATH}"

# Use gsutil to download all files with .sql extension
gsutil -m cp "${GCS_URI}*.sql" "${SCRIPTS_DIR}/" 2>/dev/null || {
    echo "Warning: No SQL scripts found at ${GCS_URI}"
    echo "Looking for scripts without path prefix..."
    gsutil -m cp "gs://${SQL_SCRIPTS_BUCKET}/*.sql" "${SCRIPTS_DIR}/" 2>/dev/null || {
        echo "Error: No SQL scripts found in bucket"
        exit 1
    }
}

# Count downloaded scripts
SCRIPT_COUNT=$(find "${SCRIPTS_DIR}" -name "*.sql" -type f | wc -l)
echo "Found ${SCRIPT_COUNT} SQL script(s)"

if [ "$SCRIPT_COUNT" -eq 0 ]; then
    echo "No SQL scripts to execute"
    exit 0
fi

# Determine which user to use
if [ "${USE_ROOT}" = "true" ]; then
    EXEC_USER="${ROOT_USER}"
    EXEC_PASSWORD="${ROOT_PASSWORD}"
    echo "Executing scripts as root user: ${ROOT_USER}"
else
    EXEC_USER="${DB_USER}"
    EXEC_PASSWORD="${DB_PASSWORD}"
    echo "Executing scripts as application user: ${DB_USER}"
fi

# Execute scripts in alphabetical order
# Scripts should be named with numeric prefixes for ordering (e.g., 001_init.sql, 002_data.sql)
for script in $(find "${SCRIPTS_DIR}" -name "*.sql" -type f | sort); do
    script_name=$(basename "$script")
    echo ""
    echo "Executing script: ${script_name}..."
    echo "----------------------------------------"

    if [ "$DB_TYPE" = "MYSQL" ]; then
        mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${EXEC_USER}" -p"${EXEC_PASSWORD}" "${DB_NAME}" < "$script"
    elif [ "$DB_TYPE" = "POSTGRES" ]; then
        PGPASSWORD="${EXEC_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${EXEC_USER}" -d "${DB_NAME}" -f "$script"
    fi

    if [ $? -eq 0 ]; then
        echo "✓ Script ${script_name} executed successfully"
    else
        echo "✗ Error executing script ${script_name}"
        exit 1
    fi
done

echo ""
echo "=== All SQL Scripts Executed Successfully ==="

# Cleanup
rm -rf "${SCRIPTS_DIR}"
