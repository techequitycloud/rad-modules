#!/bin/sh
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

set -e

echo "=== Odoo DB Initialization Job ==="

# Install dependencies
echo "Installing dependencies..."
apk update
apk add --no-cache postgresql-client jq curl

# Verify environment variables
echo "Environment Check:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_NAME: $DB_NAME"
echo "  DB_USER: $DB_USER"
echo "  PROJECT_ID: $PROJECT_ID"
echo "  APP_NAME: $APP_NAME"

# Remove spaces from the region variables
APP_REGION_1=$(echo "${APP_REGION_1}" | tr -d '[:space:]')
APP_REGION_2=$(echo "${APP_REGION_2}" | tr -d '[:space:]')

echo "  APP_REGION_1: $APP_REGION_1"
echo "  APP_REGION_2: $APP_REGION_2"

# ============================================================================
# Delete existing Cloud Run services before database initialization
# ============================================================================

# Maximum number of attempts
max_attempts=3
attempt=0
delete_attempted=false

echo ""
echo "=== Checking for existing Cloud Run services ==="

# Loop until the service no longer exists or max attempts reached
while [ $attempt -lt $max_attempts ]; do
  services_found=false # Flag to track if any services were found

  # Check and delete service in APP_REGION_1
  if [ -n "$APP_REGION_1" ]; then
    if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" 2>/dev/null; then
      echo "Cloud Run service still exists in region $APP_REGION_1. Attempting to delete..."

      # Try to delete the service
      if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_1" --quiet; then
        echo "Cloud Run service is being deleted in region $APP_REGION_1."
        delete_attempted=true
        services_found=true
      else
        echo "Failed to delete Cloud Run service in region $APP_REGION_1. Retrying..."
        services_found=true
      fi
    else
      echo "Cloud Run service does not exist in region $APP_REGION_1."
    fi
  fi

  # Check and delete service in APP_REGION_2
  if [ -n "$APP_REGION_2" ]; then
    if gcloud run services describe "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" 2>/dev/null; then
      echo "Cloud Run service still exists in region $APP_REGION_2. Attempting to delete..."

      # Try to delete the service
      if gcloud run services delete "${APP_NAME}" --project="${PROJECT_ID}" --region="$APP_REGION_2" --quiet; then
        echo "Cloud Run service is being deleted in region $APP_REGION_2."
        delete_attempted=true
        services_found=true
      else
        echo "Failed to delete Cloud Run service in region $APP_REGION_2. Retrying..."
        services_found=true
      fi
    else
      echo "Cloud Run service does not exist in region $APP_REGION_2."
    fi
  fi

  # If no services were found, exit the loop
  if ! $services_found; then
    echo "No Cloud Run services found. Proceeding with database initialization..."
    break
  fi

  # If services were found and attempted, increment attempt and retry
  attempt=$((attempt + 1))
  echo "Retrying... Attempt $attempt of $max_attempts."
  sleep 10
done

# ============================================================================
# Database Initialization
# ============================================================================

echo ""
echo "=== Starting Database Initialization ==="

# Test database connection
echo "Testing database connection..."
export PGPASSWORD="${ROOT_PASS}"
if psql -U postgres -h "${DB_HOST}" -d postgres -c 'SELECT version();' > /dev/null 2>&1; then
  echo "✓ Database connection successful"
else
  echo "✗ Database connection failed"
  exit 1
fi

# Display databases
echo ""
echo "Current databases:"
psql -U postgres -h "${DB_HOST}" -d postgres -c '\l'

# Function to check if database exists
check_database_exists() {
    local result=$(PGPASSWORD="${ROOT_PASS}" psql -U postgres -h "${DB_HOST}" -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}';" 2>/dev/null | tr -d ' \n')
    [ "$result" = "1" ]
}

# ============================================================================
# Create/Update Database User
# ============================================================================

echo ""
echo "=== Creating/Updating Database User ==="

export PGPASSWORD="${ROOT_PASS}"
psql -U postgres -h "${DB_HOST}" -d postgres <<EOF
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

echo "✓ Database user ${DB_USER} created/updated successfully"

# ============================================================================
# Drop Existing Database (if it exists)
# ============================================================================

# Set maximum retries to drop the database
max_retries=5
attempt_num=1

echo ""
echo "=== Checking for existing database ==="

# Loop until the database is dropped or we reach the max retries
while [ $attempt_num -le $max_retries ]; do
    echo "Attempt $attempt_num of $max_retries"

    # Check if the database exists using the function
    if check_database_exists; then
        echo "Database ${DB_NAME} exists, attempting to drop it..."

        echo "Terminating connections to database ${DB_NAME}..."
        export PGPASSWORD="${ROOT_PASS}"
        psql -U postgres -h "${DB_HOST}" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" 2>/dev/null || true

        # Try to drop using database owner credentials first
        echo "Dropping database using owner credentials..."
        export PGPASSWORD="${DB_PASS}"
        if psql -U "${DB_USER}" -h "${DB_HOST}" -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>&1; then
            if ! check_database_exists; then
                echo "✓ Database ${DB_NAME} dropped successfully"
                break
            fi
        fi

        # If that didn't work, try as postgres user
        echo "Trying to change database ownership to postgres..."
        export PGPASSWORD="${ROOT_PASS}"
        psql -U postgres -h "${DB_HOST}" -d postgres -c "ALTER DATABASE ${DB_NAME} OWNER TO postgres;" 2>/dev/null || true

        # Terminate connections again
        psql -U postgres -h "${DB_HOST}" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" 2>/dev/null || true

        # Try dropping as postgres
        echo "Attempting to drop as postgres user..."
        if psql -U postgres -h "${DB_HOST}" -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>&1; then
            if ! check_database_exists; then
                echo "✓ Database ${DB_NAME} dropped successfully"
                break
            fi
        fi
    else
        echo "Database ${DB_NAME} does not exist."
        break
    fi

    # Increment the attempt number
    attempt_num=$((attempt_num + 1))

    # Wait before the next attempt
    if [ $attempt_num -le $max_retries ]; then
        echo "Waiting 10 seconds before next attempt..."
        sleep 10
    fi
done

# Check if we failed to drop the database
if [ $attempt_num -gt $max_retries ] && check_database_exists; then
    echo "✗ Reached maximum number of retries. Failed to drop database ${DB_NAME}."
    echo "Database still exists - manual intervention required."
    exit 1
fi

# ============================================================================
# Create Database
# ============================================================================

echo ""
echo "=== Creating Database ==="

export PGPASSWORD="${DB_PASS}"
if ! check_database_exists; then
    if psql -U "${DB_USER}" -h "${DB_HOST}" -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>&1; then
        echo "✓ Database ${DB_NAME} created successfully"

        # Grant additional privileges
        export PGPASSWORD="${ROOT_PASS}"
        psql -U postgres -h "${DB_HOST}" -d postgres <<EOF
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
ALTER ROLE ${DB_USER} CREATEDB;
ALTER ROLE ${DB_USER} INHERIT;
EOF
        echo "✓ Database privileges granted"
    else
        echo "✗ Failed to create database"
        exit 1
    fi
else
    echo "Database already exists, skipping creation."
fi

# ============================================================================
# Initialize Odoo Database Schema (optional)
# ============================================================================

echo ""
echo "=== Database Initialization Complete ==="
echo "Database ${DB_NAME} is ready for Odoo initialization"
echo ""
echo "Note: Odoo will complete the schema initialization on first startup"

echo ""
echo "✓ Script completed successfully!"
