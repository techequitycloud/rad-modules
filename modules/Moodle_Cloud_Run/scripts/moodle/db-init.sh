set -e
echo "Installing dependencies..."
apk add --no-cache postgresql-client

TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
echo "Using DB Host: $TARGET_DB_HOST"

echo "Waiting for PostgreSQL..."
export PGPASSWORD="$ROOT_PASSWORD"
until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
  echo "Waiting for database connection..."
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
GRANT "$DB_USER" TO postgres;
GRANT ALL PRIVILEGES ON DATABASE postgres TO "$DB_USER";
EOF

echo "Creating Database $DB_NAME if not exists..."
if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  echo "Database does not exist. Creating as $DB_USER..."
  psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\" ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;"
else
  echo "Database $DB_NAME already exists."
  psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
fi

echo "Granting privileges..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

echo "Granting schema permissions..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

echo "Installing extensions..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

echo "PostgreSQL DB Init complete."