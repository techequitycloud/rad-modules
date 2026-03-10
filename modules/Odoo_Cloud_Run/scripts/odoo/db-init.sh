set -e
echo "=========================================="
echo "Database Initialization"
echo "=========================================="

echo "Environment Check:"
echo "  DB_HOST: ${DB_HOST:-NOT_SET}"
echo "  DB_PORT: 5432"
echo "  DB_USER: ${DB_USER:-NOT_SET}"
echo "  DB_NAME: ${DB_NAME:-NOT_SET}"
echo ""

if [ -z "${DB_HOST}" ]; then
  echo "ERROR: DB_HOST is not set!"
  exit 1
fi

if [ -z "${ROOT_PASSWORD}" ]; then
  echo "ERROR: ROOT_PASSWORD is not set!"
  exit 1
fi

echo "Installing tools..."
apk update && apk add --no-cache postgresql-client netcat-openbsd
echo ""

# Skip DNS check for private IPs or Unix sockets
if echo "${DB_HOST}" | grep -q "^/"; then
  echo "Detected Unix socket: ${DB_HOST}"
  echo "Skipping DNS resolution check"
elif echo "${DB_HOST}" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'; then
  echo "Detected private IP address: ${DB_HOST}"
  echo "Skipping DNS resolution check"
else
  echo "Testing DNS resolution for ${DB_HOST}..."
  nslookup ${DB_HOST} 2>&1 | grep -q "Address:" && echo "DNS OK" || echo "DNS warning"
fi
echo ""

if echo "${DB_HOST}" | grep -q "^/"; then
  echo "Skipping network connectivity check for Unix socket"
else
  echo "Testing network connectivity to ${DB_HOST}:5432..."
  if timeout 5 nc -zv ${DB_HOST} 5432 2>&1; then
    echo "Port 5432 is reachable"
  else
    echo "ERROR: Cannot reach ${DB_HOST}:5432"
    echo "Check VPC connector or use public IP"
    exit 1
  fi
fi
echo ""

echo "Connecting to database..."
export PGPASSWORD=${ROOT_PASSWORD}
export PGCONNECT_TIMEOUT=5

MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; then
    echo "Database connected after $RETRY_COUNT attempts"
    break
  fi

  RETRY_COUNT=`expr $RETRY_COUNT + 1`

  if [ `expr $RETRY_COUNT % 10` -eq 0 ]; then
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES"
    psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -c '\l' 2>&1 || true
  else
    echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
  fi

  sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Failed to connect after $MAX_RETRIES attempts"
  exit 1
fi

echo ""
echo "Creating database role..."
psql -h ${DB_HOST} -p 5432 -U postgres -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE "${DB_USER}" WITH LOGIN PASSWORD '${DB_PASSWORD}';
  ELSE
    ALTER ROLE "${DB_USER}" WITH PASSWORD '${DB_PASSWORD}';
  END IF;
END
\$\$;
ALTER ROLE "${DB_USER}" CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE postgres TO "${DB_USER}";
EOF
echo "Role configured"
echo ""

echo "Creating database..."
if ! psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  export PGPASSWORD=${DB_PASSWORD}
  psql -h ${DB_HOST} -p 5432 -U ${DB_USER} -d postgres -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
  echo "Database created"
else
  echo "Database already exists"
fi
echo ""

export PGPASSWORD=${ROOT_PASSWORD}
psql -h ${DB_HOST} -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"
echo "Privileges granted"
echo ""
echo "Database initialization complete"