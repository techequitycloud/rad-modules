set -e
echo "Installing dependencies..."
apk update && apk add --no-cache postgresql-client

# Use DB_HOST which is configured to be socket or IP
TARGET_DB_HOST="${DB_HOST}"
echo "Using DB Host: $TARGET_DB_HOST"

echo "Waiting for database..."
export PGPASSWORD=$ROOT_PASSWORD
until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
  echo "Waiting for database connection at $TARGET_DB_HOST..."
  sleep 2
done

echo "Creating Role $DB_USER if not exists..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
  ELSE
    ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
  END IF;
END
\$\$;
ALTER ROLE "$DB_USER" CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
EOF

echo "Creating Database $DB_NAME if not exists..."
if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  echo "Database does not exist. Creating as $DB_USER..."
  export PGPASSWORD=$DB_PASSWORD
  psql -h "$TARGET_DB_HOST" -p 5432 -U $DB_USER -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
else
  echo "Database $DB_NAME already exists."
fi

echo "Granting privileges..."
export PGPASSWORD=$ROOT_PASSWORD
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

echo "DB Init complete."