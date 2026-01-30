#!/bin/bash
set -e

echo "Starting Directus initialization for Cloud Run..."

# Function to wait for Cloud SQL database
wait_for_db() {
    if [ -n "$DB_HOST" ] && [ "$DB_CLIENT" != "sqlite3" ]; then
        echo "Waiting for Cloud SQL database at $DB_HOST:${DB_PORT:-5432}..."
        
        local max_attempts=60  # Increased for Cloud SQL Private IP
        local attempt=0
        
        while [ "$attempt" -lt "$max_attempts" ]; do
            if pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "${DB_USER:-directus}" > /dev/null 2>&1; then
                echo "Database is ready!"
                return 0
            fi
            
            attempt=$((attempt + 1))
            echo "Waiting for database... (attempt $attempt/$max_attempts)"
            sleep 2
        done
        
        echo "ERROR: Database connection timeout after $max_attempts attempts"
        exit 1  # Fail fast on Cloud Run
    fi
}

# Function to check GCS storage configuration
check_gcs_storage() {
    if [ "$STORAGE_LOCATIONS" = "gcs" ]; then
        if [ -z "$STORAGE_GCS_BUCKET" ]; then
            echo "ERROR: STORAGE_GCS_BUCKET is not set"
            exit 1
        fi
        
        if [ -z "$STORAGE_GCS_PROJECT_ID" ]; then
            echo "WARNING: STORAGE_GCS_PROJECT_ID not set, using default credentials"
        fi
        
        echo "GCS Storage configured: bucket=$STORAGE_GCS_BUCKET"
    else
        echo "WARNING: Not using GCS storage. Cloud Run requires external storage!"
    fi
}

# Function to verify Cloud Run environment
check_cloud_run_env() {
    if [ -n "$K_SERVICE" ]; then
        echo "Running on Cloud Run: $K_SERVICE"
        echo "Cloud Run Revision: ${K_REVISION:-unknown}"
        echo "Cloud Run Configuration: ${K_CONFIGURATION:-unknown}"
        
        # Use Cloud Run's PORT if available
        if [ -n "$PORT" ]; then
            export PORT="$PORT"
            echo "Using Cloud Run PORT: $PORT"
        fi
    else
        echo "Not running on Cloud Run (K_SERVICE not set)"
    fi
}

# Check Cloud Run environment
check_cloud_run_env

# Wait for database
wait_for_db

# Check GCS storage configuration
check_gcs_storage

# Run database migrations if AUTO_MIGRATE is enabled
if [ "$AUTO_MIGRATE" = "true" ]; then
    echo "Running database migrations..."
    if npx directus database migrate:latest; then
        echo "✅ Database migrations completed successfully"
    else
        echo "ERROR: Database migration failed"
        exit 1  # Fail fast on Cloud Run
    fi
fi

# Bootstrap database if BOOTSTRAP is enabled (first deployment only)
if [ "$BOOTSTRAP" = "true" ]; then
    echo "Bootstrapping Directus database..."
    if npx directus bootstrap; then
        echo "✅ Database bootstrap completed successfully"
    else
        echo "WARNING: Bootstrap failed or already completed"
    fi
fi

echo "Starting Directus on port ${PORT:-8055}..."

# Execute the command passed to the script
exec "$@"
