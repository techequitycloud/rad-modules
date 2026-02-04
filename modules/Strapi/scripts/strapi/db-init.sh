set -e
echo "Installing dependencies..."
apk update && apk add --no-cache postgresql-client

# Use DB_IP if available, else DB_HOST
TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
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
GRANT "$DB_USER" TO postgres;
ALTER ROLE "$DB_USER" CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
EOF

echo "Creating Database $DB_NAME if not exists..."
if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  echo "Database does not exist. Creating..."
  # Create database with owner set to DB_USER
  psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
else
  echo "Database $DB_NAME already exists. Updating owner..."
  psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
fi

echo "Granting privileges..."
export PGPASSWORD=$ROOT_PASSWORD
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

echo "Granting schema permissions..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

echo "DB Init complete."