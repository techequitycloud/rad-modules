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
GRANT ALL PRIVILEGES ON DATABASE postgres TO "${DB_USER}";
EOF

echo "Creating Database ${DB_NAME} if not exists..."
if ! psql -h "${DB_HOST}" -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database does not exist. Creating as ${DB_USER}..."
  
  # Switch to user credentials to create the DB (ensures ownership)
  export PGPASSWORD="${DB_PASS}"
  if psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE \"${DB_NAME}\";"; then
    echo "Database created successfully."
  else
    echo "Failed to create database as ${DB_USER}."
    exit 1
  fi

  # Revert to root password for subsequent commands if any
  export PGPASSWORD="${ROOT_PASS}"
else
  echo "Database ${DB_NAME} already exists."
fi

echo "Granting privileges..."
# Owner has all privileges, but we can ensure it here if needed.
psql -h "${DB_HOST}" -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"

echo "Initialization complete."
