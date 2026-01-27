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
# Install PostgreSQL Extensions
#########################################################################

set -e

# Required environment variables:
# - POSTGRES_EXTENSIONS: Comma-separated list of extensions to install
# - DB_HOST: Database host
# - DB_PORT: Database port
# - DB_NAME: Database name
# - ROOT_USER: Database root username (typically 'postgres')
# - ROOT_PASSWORD: Database root password

echo "=== PostgreSQL Extensions Installation Job ==="
echo "Extensions to install: ${POSTGRES_EXTENSIONS}"
echo "Database: ${DB_NAME}"

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
apt-get update -qq && apt-get install -y -qq postgresql-client

# Ensure database exists before installing extensions
echo "Checking if database ${DB_NAME} exists..."
if ! PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database ${DB_NAME} does not exist. Creating it..."
  PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "postgres" -c "CREATE DATABASE \"${DB_NAME}\";"
  echo "✓ Database ${DB_NAME} created successfully"
else
  echo "Database ${DB_NAME} already exists."
fi

# Verify we can connect to the database (handles case where CONNECT was revoked by failed cleanup)
echo "Verifying connection to database ${DB_NAME}..."
if ! PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "${DB_NAME}" -c "SELECT 1" >/dev/null 2>&1; then
  echo "⚠️  Cannot connect to database ${DB_NAME}. Attempting to restore CONNECT privilege..."
  PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "postgres" -c "GRANT CONNECT ON DATABASE \"${DB_NAME}\" TO \"${ROOT_USER}\", PUBLIC;" 2>/dev/null || true

  # Retry connection
  if ! PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "${DB_NAME}" -c "SELECT 1" >/dev/null 2>&1; then
    echo "❌ ERROR: Still cannot connect to database ${DB_NAME} after restoring privileges."
    echo "The database may be in an inconsistent state from a failed cleanup."
    echo "Please manually check the database or run: DROP DATABASE IF EXISTS \"${DB_NAME}\";"
    exit 1
  fi
  echo "✓ CONNECT privilege restored successfully"
fi

# Parse comma-separated extensions list
IFS=',' read -ra EXTENSIONS <<< "$POSTGRES_EXTENSIONS"

# Install each extension
for extension in "${EXTENSIONS[@]}"; do
    # Trim whitespace
    extension=$(echo "$extension" | xargs)

    if [ -z "$extension" ]; then
        continue
    fi

    echo "Installing extension: ${extension}..."

    # Use root user to create extensions
    PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "${DB_NAME}" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS ${extension};
EOSQL

    if [ $? -eq 0 ]; then
        echo "✓ Extension ${extension} installed successfully"
    else
        echo "⚠ Warning: Failed to install extension ${extension}"
        # Continue with other extensions even if one fails
    fi
done

# Verify installed extensions
echo ""
echo "Installed extensions in database ${DB_NAME}:"
PGPASSWORD="${ROOT_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${ROOT_USER}" -d "${DB_NAME}" -c "\dx"

echo ""
echo "=== PostgreSQL Extensions Installation Complete ==="
