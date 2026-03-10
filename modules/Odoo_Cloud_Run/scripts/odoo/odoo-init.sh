set -e
echo "=========================================="
echo "Odoo Database Initialization"
echo "=========================================="

echo "Mounted filesystems:"
df -h | grep -E '(Filesystem|/mnt)'
echo ""

echo "Checking NFS mount..."
if [ ! -d /mnt ]; then
    echo "ERROR: /mnt not found"
    exit 1
fi

echo "NFS contents:"
ls -la /mnt/ || exit 1
echo ""

echo "Checking GCS mount..."
if [ ! -d /mnt/extra-addons ]; then
    echo "ERROR: /mnt/extra-addons not found"
    exit 1
fi
ls -la /mnt/extra-addons || exit 1
echo "GCS mount verified"
echo ""

echo "Waiting for odoo.conf..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if [ -f /mnt/odoo.conf ]; then
    echo "Config file found"
    break
  fi
  RETRY_COUNT=`expr $RETRY_COUNT + 1`
  echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
  sleep 2
done

if [ ! -f /mnt/odoo.conf ]; then
  echo "ERROR: /mnt/odoo.conf not found"
  ls -la /mnt/
  exit 1
fi
echo ""

echo "Verifying config file..."
if ! cat /mnt/odoo.conf > /dev/null 2>&1; then
  echo "ERROR: Cannot read /mnt/odoo.conf"
  ls -la /mnt/odoo.conf
  exit 1
fi
echo "Config file readable"
echo ""

echo "Checking filestore..."
if [ ! -d /mnt/filestore ]; then
    echo "ERROR: /mnt/filestore not found"
    exit 1
fi
echo "Filestore found"
echo ""

echo "Testing write access..."
if ! touch /mnt/filestore/.test 2>/dev/null; then
    echo "ERROR: Cannot write to /mnt/filestore"
    ls -la /mnt/filestore/
    exit 1
fi
rm -f /mnt/filestore/.test
echo "Filestore writable"
echo ""

echo "Checking if DB already initialized..."
if psql "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:5432/${DB_NAME}" \
     -c "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module';" 2>/dev/null | grep -q 1; then
    echo "Database already initialized"
    exit 0
fi
echo "Initializing database..."
echo ""

echo "=========================================="
echo "Starting Odoo initialization..."
echo "=========================================="
odoo -c /mnt/odoo.conf -i base --stop-after-init --log-level=info

echo ""
echo "Odoo initialization complete"