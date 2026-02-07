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
    # Parse DB_VERSION if provided (e.g. POSTGRES_16 -> 16, POSTGRES_9_6 -> 9.6)
    PG_MAJOR_VERSION=""
    if [ -n "$DB_VERSION" ]; then
        if [[ "$DB_VERSION" =~ POSTGRES_([0-9_]+) ]]; then
            PG_MAJOR_VERSION="${BASH_REMATCH[1]//_/.}"
        elif [[ "$DB_VERSION" =~ ^[0-9]+$ ]]; then
            PG_MAJOR_VERSION="$DB_VERSION"
        fi
    fi

    if [ -n "$PG_MAJOR_VERSION" ]; then
        echo "Detected PostgreSQL version: $PG_MAJOR_VERSION"
        echo "Installing postgresql-client-$PG_MAJOR_VERSION..."

        apt-get update -qq
        apt-get install -y -qq gnupg lsb-release curl ca-certificates

        echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
        curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

        apt-get update -qq
        apt-get install -y -qq postgresql-client-$PG_MAJOR_VERSION
    else
        apt-get update -qq && apt-get install -y -qq postgresql-client
    fi
elif [ "$DB_TYPE" = "SQLSERVER" ]; then
    echo "SQL Server backup import not yet implemented"
    exit 1
else
    echo "Unknown database type: ${DB_TYPE}"
    exit 1
fi

# Handle Directory/Bucket Root URI (Auto-Discovery)
# If URI ends with / or does not look like a file, try to find the latest backup
if [[ "${GCS_BACKUP_URI}" == */ ]] || [[ "${GCS_BACKUP_URI}" != *.* ]]; then
    echo "GCS URI appears to be a directory or bucket root. Attempting to find latest backup..."

    # List files, sort by time (latest last), take the last one
    # Assuming standard naming convention or just taking latest file
    LATEST_BACKUP=$(gsutil ls -l "${GCS_BACKUP_URI}**" | grep -v "/$" | sort -k 2 | tail -n 1 | awk '{print $NF}')

    if [ -z "${LATEST_BACKUP}" ]; then
        echo "Error: No backup files found in ${GCS_BACKUP_URI}"
        exit 1
    fi

    echo "Found latest backup: ${LATEST_BACKUP}"
    GCS_BACKUP_URI="${LATEST_BACKUP}"

    # Attempt to detect format from extension if set to auto
    if [ "${BACKUP_FORMAT}" = "auto" ]; then
        if [[ "${LATEST_BACKUP}" == *.sql ]]; then
            BACKUP_FORMAT="sql"
        elif [[ "${LATEST_BACKUP}" == *.tar.gz ]] || [[ "${LATEST_BACKUP}" == *.tgz ]]; then
            BACKUP_FORMAT="tar.gz"
        elif [[ "${LATEST_BACKUP}" == *.zip ]]; then
            BACKUP_FORMAT="zip"
        elif [[ "${LATEST_BACKUP}" == *.tar ]]; then
            BACKUP_FORMAT="tar"
        else
            echo "Warning: Could not detect format from file extension. Defaulting to sql."
            BACKUP_FORMAT="sql"
        fi
        echo "Auto-detected format: ${BACKUP_FORMAT}"
    fi
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

        # Extract other files to NFS if mounted
        if [ -n "${NFS_MOUNT_PATH}" ] && [ -d "${NFS_MOUNT_PATH}" ]; then
            echo "NFS mount detected at ${NFS_MOUNT_PATH}. Copying extracted files..."
            rsync -a --exclude "$(basename "${SQL_FILE}")" /tmp/backup_extracted/ "${NFS_MOUNT_PATH}/"
            echo "✓ Files copied to NFS volume"
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

        # GZ format is just a compressed SQL file, no NFS files expected
        # NFS restoration only applies to archive formats (tar, tar.gz, zip)
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

        # Extract other files to NFS if mounted
        if [ -n "${NFS_MOUNT_PATH}" ] && [ -d "${NFS_MOUNT_PATH}" ]; then
            echo "NFS mount detected at ${NFS_MOUNT_PATH}. Copying extracted files..."
            rsync -a --exclude "$(basename "${SQL_FILE}")" /tmp/backup_extracted/ "${NFS_MOUNT_PATH}/"
            echo "✓ Files copied to NFS volume"
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
