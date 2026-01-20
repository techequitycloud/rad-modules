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
# Import Database Backup from Google Cloud Storage
#########################################################################

set -e

# Required environment variables:
# - GCS_BACKUP_URI: Full GCS URI (gs://bucket-name/path/to/backup.sql)
# - BACKUP_FORMAT: Format of the backup file (sql, tar, gz, zip)
# - DB_TYPE: Database type (MYSQL, POSTGRES, SQLSERVER)
# - DB_HOST: Database host
# - DB_PORT: Database port
# - DB_NAME: Database name
# - DB_USER: Database username
# - DB_PASSWORD: Database password
# - ROOT_PASSWORD: Database root password (for MySQL)

echo "=== Google Cloud Storage Backup Import Job ==="
echo "GCS URI: ${GCS_BACKUP_URI}"
echo "Backup Format: ${BACKUP_FORMAT}"
echo "Database Type: ${DB_TYPE}"
echo "Database: ${DB_NAME}"

# Install required packages
echo "Installing required packages..."
if [ "$DB_TYPE" = "MYSQL" ]; then
    apt-get update -qq && apt-get install -y -qq default-mysql-client
elif [ "$DB_TYPE" = "POSTGRES" ]; then
    apt-get update -qq && apt-get install -y -qq postgresql-client
elif [ "$DB_TYPE" = "SQLSERVER" ]; then
    echo "SQL Server backup import not yet implemented"
    exit 1
else
    echo "Unknown database type: ${DB_TYPE}"
    exit 1
fi

# Download backup file from GCS using gsutil (pre-installed in Cloud Run)
BACKUP_FILE="/tmp/backup.${BACKUP_FORMAT}"
echo "Downloading backup from GCS..."
gsutil cp "${GCS_BACKUP_URI}" "${BACKUP_FILE}"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Error: Failed to download backup file from GCS"
    exit 1
fi

echo "Backup file downloaded successfully: ${BACKUP_FILE}"
ls -lh "${BACKUP_FILE}"

# Import backup based on format and database type
case "${BACKUP_FORMAT}" in
    sql)
        echo "Importing SQL dump..."
        if [ "$DB_TYPE" = "MYSQL" ]; then
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "${BACKUP_FILE}"
        elif [ "$DB_TYPE" = "POSTGRES" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${BACKUP_FILE}"
        fi
        ;;
    tar|tgz|tar.gz)
        echo "Extracting tarball and importing..."
        mkdir -p /tmp/backup_extracted
        tar -xzf "${BACKUP_FILE}" -C /tmp/backup_extracted

        # Look for SQL file in extracted directory
        SQL_FILE=$(find /tmp/backup_extracted -name "*.sql" -type f | head -n 1)
        if [ -z "$SQL_FILE" ]; then
            echo "Error: No SQL file found in tarball"
            exit 1
        fi

        echo "Found SQL file: ${SQL_FILE}"
        if [ "$DB_TYPE" = "MYSQL" ]; then
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "${SQL_FILE}"
        elif [ "$DB_TYPE" = "POSTGRES" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${SQL_FILE}"
        fi
        ;;
    gz)
        echo "Decompressing gzip and importing..."
        apt-get install -y -qq gzip
        gunzip -c "${BACKUP_FILE}" > /tmp/backup.sql

        if [ "$DB_TYPE" = "MYSQL" ]; then
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < /tmp/backup.sql
        elif [ "$DB_TYPE" = "POSTGRES" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f /tmp/backup.sql
        fi
        ;;
    zip)
        echo "Extracting zip and importing..."
        apt-get install -y -qq unzip
        mkdir -p /tmp/backup_extracted
        unzip -q "${BACKUP_FILE}" -d /tmp/backup_extracted

        # Look for SQL file in extracted directory
        SQL_FILE=$(find /tmp/backup_extracted -name "*.sql" -type f | head -n 1)
        if [ -z "$SQL_FILE" ]; then
            echo "Error: No SQL file found in zip archive"
            exit 1
        fi

        echo "Found SQL file: ${SQL_FILE}"
        if [ "$DB_TYPE" = "MYSQL" ]; then
            mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" < "${SQL_FILE}"
        elif [ "$DB_TYPE" = "POSTGRES" ]; then
            PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${SQL_FILE}"
        fi
        ;;
    *)
        echo "Error: Unsupported backup format: ${BACKUP_FORMAT}"
        exit 1
        ;;
esac

echo "✓ Backup imported successfully from GCS"

# Cleanup
rm -f "${BACKUP_FILE}"
rm -rf /tmp/backup_extracted

echo "=== Import Complete ==="
