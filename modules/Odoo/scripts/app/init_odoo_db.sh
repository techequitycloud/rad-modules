#!/bin/sh
set -e

echo "=== Odoo Init Job Starting ==="
echo "Timestamp: $(date)"
echo ""

echo "Environment Variables:"
echo "  DB_HOST=$DB_HOST"
echo "  DB_PORT=${DB_PORT:-5432}"
echo "  DB_NAME=$DB_NAME"
echo "  DB_USER=$DB_USER"
echo "  DATA_DIR=${DATA_DIR:-/mnt/filestore}"
echo ""

echo "Checking mounts..."
echo "NFS mount:"
ls -la /mnt/ || echo "NFS mount check failed"
echo ""
echo "GCS mount:"
ls -la /extra-addons/ || echo "GCS mount check failed"
echo ""

echo "Starting Odoo initialization..."
echo "Command: odoo -d $DB_NAME --db_host=$DB_HOST --db_port=5432 --db_user=$DB_USER --data-dir=/mnt/filestore -i base --stop-after-init --log-level=info"
echo ""

# Run Odoo with explicit parameters
exec odoo \
  -d "$DB_NAME" \
  --db_host="$DB_HOST" \
  --db_port=5432 \
  --db_user="$DB_USER" \
  --db_password="$DB_PASSWORD" \
  --data-dir=/mnt/filestore \
  --addons-path=/usr/lib/python3/dist-packages/odoo/addons,/extra-addons \
  -i base \
  --stop-after-init \
  --log-level=info
