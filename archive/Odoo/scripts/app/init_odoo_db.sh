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

# Check if /extra-addons has any content
ADDONS_PATH="/usr/lib/python3/dist-packages/odoo/addons"
if [ -d "/extra-addons" ] && [ "$(ls -A /extra-addons 2>/dev/null)" ]; then
  echo "Extra addons found, including in path"
  ADDONS_PATH="$ADDONS_PATH,/extra-addons"
else
  echo "No extra addons found, using default path only"
fi

echo "Starting Odoo initialization..."
echo "Addons path: $ADDONS_PATH"
echo ""

# Run Odoo with explicit parameters
exec odoo \
  -d "$DB_NAME" \
  --db_host="$DB_HOST" \
  --db_port="$DB_PORT" \
  --db_user="$DB_USER" \
  --db_password="$DB_PASSWORD" \
  --data-dir="$DATA_DIR" \
  --addons-path="$ADDONS_PATH" \
  -i base \
  --stop-after-init \
  --log-level=info
