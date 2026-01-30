#!/bin/bash
set -e

# Moodle entrypoint script
# Sets up database connection parameters and starts the application

: ${DB_HOST:='127.0.0.1'}
: ${DB_PORT:=5432}
: ${DB_USER:='moodle'}
: ${DB_PASSWORD:='moodle'}
: ${DB_NAME:='moodle'}
: ${PORT:=8080}

echo "Starting Moodle..."
echo "Database Host: $DB_HOST"
echo "Database Port: $DB_PORT"
echo "Database Name: $DB_NAME"

# Set permissions for data directory
if [ -d "/mnt" ]; then
    chown -R www-data:www-data /mnt 2>/dev/null || true
fi

# Execute the command passed to the container
exec "$@"
