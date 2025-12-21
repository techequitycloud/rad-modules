#!/bin/sh
set -e

echo "=== DB Import/Setup Job ==="

# Install dependencies
echo "Installing dependencies..."
apk update
apk add --no-cache postgresql-client

# Verify vars
echo "DB_HOST: $DB_HOST"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"

# Export PGPASSWORD for root (default used by psql)
export PGPASSWORD="${ROOT_PASS}"

echo "Checking DB connection..."
# Try to connect for up to 60 seconds
for i in $(seq 1 30); do
  if psql -h "${DB_HOST}" -U postgres -d postgres -c '\l' > /dev/null 2>&1; then
    echo "Connected to database."
    break
  fi
  echo "Waiting for database connection... ($i/30)"
  sleep 2
done

echo "Creating Role ${DB_USER} if not exists..."
psql -h "${DB_HOST}" -U postgres -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
    CREATE ROLE "${DB_USER}" WITH LOGIN PASSWORD '${DB_PASS}';
  ELSE
    ALTER ROLE "${DB_USER}" WITH PASSWORD '${DB_PASS}';
  END IF;
END
\$\$;
ALTER ROLE "${DB_USER}" CREATEDB;
EOF

echo "Creating Database ${DB_NAME} if not exists..."
if ! psql -h "${DB_HOST}" -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  psql -h "${DB_HOST}" -U postgres -d postgres -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\";"
  echo "Database created."
else
  echo "Database ${DB_NAME} already exists."
fi

echo "Granting privileges..."
psql -h "${DB_HOST}" -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"

echo "Initialization complete."
