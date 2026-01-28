#!/bin/bash
set -e

echo "Starting Directus initialization..."

# Function to wait for database
wait_for_db() {
    if [ -n "$DB_HOST" ] && [ "$DB_CLIENT" != "sqlite3" ]; then
        echo "Waiting for database at $DB_HOST:${DB_PORT:-5432}..."
        
        local max_attempts=30
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            if pg_isready -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "${DB_USER:-directus}" > /dev/null 2>&1; then
                echo "Database is ready!"
                return 0
            fi
            
            attempt=$((attempt + 1))
            echo "Waiting for database... (attempt $attempt/$max_attempts)"
            sleep 2
        done
        
        echo "Warning: Database connection timeout. Proceeding anyway..."
    fi
}

# Function to check if uploads directory is writable
check_uploads_dir() {
    if [ -d "$STORAGE_LOCAL_ROOT" ]; then
        if [ -w "$STORAGE_LOCAL_ROOT" ]; then
            echo "Uploads directory is writable: $STORAGE_LOCAL_ROOT"
        else
            echo "Warning: Uploads directory is not writable: $STORAGE_LOCAL_ROOT"
        fi
    else
        echo "Warning: Uploads directory does not exist: $STORAGE_LOCAL_ROOT"
    fi
}

# Wait for database
wait_for_db

# Check uploads directory
check_uploads_dir

# Run database migrations if AUTO_MIGRATE is enabled
if [ "$AUTO_MIGRATE" = "true" ]; then
    echo "Running database migrations..."
    npx directus database migrate:latest || echo "Migration failed or not needed"
fi

echo "Starting Directus..."

# Execute the command passed to the script
exec "$@"
