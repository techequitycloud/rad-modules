#!/bin/bash
# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail

echo "=== Odoo Cloud Run Entrypoint Started ==="

# Set database variables from environment
: ${DB_HOST:='127.0.0.1'}
: ${DB_PORT:=5432}
: ${DB_USER:=${POSTGRES_USER:='odoo'}}
: ${DB_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}
: ${DB_NAME:='odoo'}
: ${FORCE_REINIT:='false'}

echo "Database Configuration:"
echo "  Host: ${DB_HOST}"
echo "  Port: ${DB_PORT}"
echo "  User: ${DB_USER}"
echo "  Name: ${DB_NAME}"
echo "  Force Reinit: ${FORCE_REINIT}"

# Set permissions for directories (if running as root)
if [ "$(id -u)" = "0" ]; then
    echo "Setting permissions for odoo user..."
    chown -R odoo:odoo /mnt /extra-addons 2>/dev/null || true
fi

# Update odoo.conf with database name
echo "Configuring Odoo..."
sed -i "s|DB_NAME|${DB_NAME}|g" /etc/odoo/odoo.conf

# ✅ Wait for PostgreSQL to be ready with proper arguments
echo "Waiting for PostgreSQL to be ready..."
python3 /usr/local/bin/wait-for-psql.py \
    --db_host="${DB_HOST}" \
    --db_port="${DB_PORT}" \
    --db_user="${DB_USER}" \
    --db_password="${DB_PASSWORD}" \
    --timeout=60

echo "PostgreSQL is ready!"

# Database initialization flag
INIT_FLAG="/mnt/.odoo_db_initialized_${DB_NAME}"

# Check if database needs initialization
if [ ! -f "$INIT_FLAG" ]; then
    echo "=== Database '${DB_NAME}' not initialized. Running initialization... ==="
    
    # Run Odoo initialization with base module
    odoo \
        --db_host="${DB_HOST}" \
        --db_port="${DB_PORT}" \
        --db_user="${DB_USER}" \
        --db_password="${DB_PASSWORD}" \
        --database="${DB_NAME}" \
        -i base \
        --stop-after-init \
        --without-demo=all \
        --no-http \
        --log-level=info
    
    # Check if initialization was successful
    if [ $? -eq 0 ]; then
        # Create initialization flag
        touch "$INIT_FLAG"
        echo "=== Database initialization completed successfully! ==="
    else
        echo "ERROR: Database initialization failed!"
        exit 1
    fi
else
    echo "=== Database '${DB_NAME}' already initialized. Skipping initialization. ==="
fi

echo "=== Starting Odoo server... ==="

# Start Odoo server
exec "$@"
