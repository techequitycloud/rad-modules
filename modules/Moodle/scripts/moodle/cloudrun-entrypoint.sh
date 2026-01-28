#!/usr/bin/env bash
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

echo "Starting Moodle initialization..."

# Handle signals properly
trap 'echo "Received SIGTERM, shutting down..."; exit 0' SIGTERM SIGINT

# Wait a moment for volumes to be mounted
sleep 2

# Check if data directory is accessible
if [ ! -d "/mnt" ]; then
    echo "ERROR: Data directory /mnt not accessible"
    exit 1
fi

echo "Data directory accessible: /mnt"

# Create required subdirectories if they don't exist
mkdir -p /mnt/filedir /mnt/temp /mnt/cache /mnt/localcache 2>/dev/null || true

# Verify config.php exists
if [ ! -f "/var/www/html/config.php" ]; then
    echo "ERROR: config.php not found"
    exit 1
fi

echo "Configuration file found"

# Set environment variables for Apache
export APACHE_RUN_USER=www-data
export APACHE_RUN_GROUP=www-data
export APACHE_LOG_DIR=/var/log/apache2
export APACHE_PID_FILE=/var/run/apache2/apache2.pid
export APACHE_RUN_DIR=/var/run/apache2
export APACHE_LOCK_DIR=/var/lock/apache2

echo "Moodle initialization complete"
echo "Starting Apache..."

# Execute the command passed as arguments
exec "$@"
