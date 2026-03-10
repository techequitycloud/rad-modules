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
# Export Database and NFS Backup to GCS
#########################################################################

set -e

# Required environment variables:
# - GCS_BACKUP_BUCKET: GCS bucket to upload backup to (without gs:// prefix)
# - DB_TYPE: Database type (MYSQL, POSTGRES, SQLSERVER)
# - DB_HOST: Database host
# - DB_PORT: Database port
# - DB_NAME: Database name
# - DB_USER: Database username
# - DB_PASSWORD: Database password
# - NFS_MOUNT_PATH: Path where NFS is mounted (optional)

echo "=== Export Backup Job ==="
echo "Target Bucket: gs://${GCS_BACKUP_BUCKET}"
echo "Database Type: ${DB_TYPE}"
echo "Database: ${DB_NAME}"

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_DIR="/tmp/backup_${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

# 1. Export Database
echo "Exporting database..."
DB_FILE="${BACKUP_DIR}/database.sql"

if [ "$DB_TYPE" = "MYSQL" ]; then
    # Install client if missing (should be in image, but safe check)
    if ! command -v mysqldump &> /dev/null; then
        echo "Installing mysql-client..."
        apt-get update -qq && apt-get install -y -qq default-mysql-client
    fi
    mysqldump -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" > "${DB_FILE}"
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
    elif ! command -v pg_dump &> /dev/null; then
        echo "Installing postgresql-client..."
        apt-get update -qq && apt-get install -y -qq postgresql-client
    fi

    PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${DB_FILE}"
elif [ "$DB_TYPE" = "SQLSERVER" ]; then
    echo "SQL Server export not supported yet."
    exit 1
fi

if [ -f "${DB_FILE}" ]; then
    echo "✓ Database exported successfully ($(du -h "${DB_FILE}" | cut -f1))"
else
    echo "✗ Database export failed"
    exit 1
fi

# 2. Export NFS Files (if mounted)
if [ -n "${NFS_MOUNT_PATH}" ] && [ -d "${NFS_MOUNT_PATH}" ]; then
    echo "Exporting NFS files from ${NFS_MOUNT_PATH}..."
    # Copy NFS files to backup directory under 'nfs_files' folder
    # Use rsync to preserve attributes where possible, but we are copying from NFS to local tmp
    mkdir -p "${BACKUP_DIR}/nfs_files"

    if ! command -v rsync &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq rsync
    fi

    rsync -a "${NFS_MOUNT_PATH}/" "${BACKUP_DIR}/nfs_files/"
    echo "✓ NFS files copied successfully"
else
    echo "No NFS mount detected or configured. Skipping NFS backup."
fi

# 3. Create Archive
echo "Creating backup archive..."
ARCHIVE_NAME="backup-${TIMESTAMP}.tar.gz"
tar -czf "/tmp/${ARCHIVE_NAME}" -C "${BACKUP_DIR}" .

echo "✓ Archive created: ${ARCHIVE_NAME} ($(du -h "/tmp/${ARCHIVE_NAME}" | cut -f1))"

# 4. Upload to GCS
echo "Uploading to GCS..."
gsutil cp "/tmp/${ARCHIVE_NAME}" "gs://${GCS_BACKUP_BUCKET}/backups/${ARCHIVE_NAME}"

if [ $? -eq 0 ]; then
    echo "✓ Backup uploaded successfully to gs://${GCS_BACKUP_BUCKET}/backups/${ARCHIVE_NAME}"
else
    echo "✗ Upload failed"
    exit 1
fi

# Cleanup
rm -rf "${BACKUP_DIR}"
rm -f "/tmp/${ARCHIVE_NAME}"

echo "=== Backup Complete ==="
