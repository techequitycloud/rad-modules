#!/bin/bash
set -e

echo "=== Sample DB Init Script ==="

# Use DB_IP if available (injected by WebApp), else DB_HOST
TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"

# Check if we are using Unix Socket
if [[ "$TARGET_DB_HOST" == /* ]]; then
    echo "Using Unix Socket: $TARGET_DB_HOST"
else
    echo "Using TCP Host: $TARGET_DB_HOST"
fi

echo "Waiting for database..."
export PGPASSWORD="$ROOT_PASSWORD"

# pg_isready checks connection
until pg_isready -h "$TARGET_DB_HOST" -p 5432 -U postgres; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

echo "Creating/Updating User $DB_USER..."

# Use stdin to avoid exposing password in process list
psql -h "$TARGET_DB_HOST" -U postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
  ELSE
    ALTER USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
EOF

echo "Checking Database $DB_NAME..."
# Check if DB exists
if ! psql -h "$TARGET_DB_HOST" -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    echo "Creating Database $DB_NAME..."
    psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
else
    echo "Database $DB_NAME already exists. Updating owner..."
    psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
fi

echo "Granting privileges..."
psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

echo "Sample DB Init complete."
