set -e
echo "Installing dependencies..."
apk update && apk add --no-cache postgresql-client

TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
echo "Using DB Host: $TARGET_DB_HOST"

# Wait for PostgreSQL
until pg_isready -h "$TARGET_DB_HOST" -p 5432; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

export PGPASSWORD=$ROOT_PASSWORD

echo "Creating User $DB_USER if not exists..."
# Check if user exists
if ! psql -h "$TARGET_DB_HOST" -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
else
    psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER USER \"$DB_USER\" WITH PASSWORD '$DB_PASSWORD';"
fi

# Grant user role to postgres to allow setting owner
echo "Granting role $DB_USER to postgres..."
psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT \"$DB_USER\" TO postgres;"

echo "Creating Database $DB_NAME if not exists..."
# Check if database exists
if ! psql -h "$TARGET_DB_HOST" -U postgres -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    psql -h "$TARGET_DB_HOST" -U postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";"
else
    psql -h "$TARGET_DB_HOST" -U postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"
fi

echo "Granting privileges..."
psql -h "$TARGET_DB_HOST" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"$DB_NAME\" TO \"$DB_USER\";"

# Allow user to create schema in public
psql -h "$TARGET_DB_HOST" -U postgres -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"

echo "PostgreSQL DB Init complete."