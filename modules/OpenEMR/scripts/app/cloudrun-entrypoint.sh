#!/bin/sh
#
# Copyright 2024 Tech Equity Ltd
#

set -e

echo "=== OpenEMR Cloud Run Entrypoint ==="
echo "Starting at: $(date)"

# Wait for database connection
echo "Waiting for database connection..."
if [ -f /usr/local/bin/db_check.php ]; then
    php /usr/local/bin/db_check.php
else
    echo "db_check.php not found, skipping check."
fi

echo "Database connection confirmed (or skipped)."

# Execute the original entrypoint logic via openemr.sh
# We expect openemr.sh to be at the root, as copied in the Dockerfile
if [ -f "/openemr.sh" ]; then
    echo "Executing /openemr.sh..."
    exec /openemr.sh "$@"
else
    echo "CRITICAL: /openemr.sh not found. This will likely fail."
    echo "Falling back to executing command directly..."
    exec "$@"
fi
