set -e
echo "=== PostgreSQL Extension Setup ==="

# Install PostgreSQL client
apk update && apk add --no-cache postgresql-client

# Use DB_IP if available (injected by CloudRunApp), else DB_HOST
TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
echo "Using DB Host: $TARGET_DB_HOST"

# Wait for database
echo "Waiting for PostgreSQL..."
export PGPASSWORD=$ROOT_PASSWORD
until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
  echo "Waiting for database connection..."
  sleep 2
done
echo "✓ Database is ready"

# Create database if it doesn't exist (as postgres user)
echo "Creating database $DB_NAME if not exists..."
if ! psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
  echo "Creating database..."
  psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "CREATE DATABASE \"$DB_NAME\";"
  echo "✓ Database created"
else
  echo "✓ Database already exists"
fi

# Create extensions (as postgres user - has cloudsqlsuperuser role)
echo "Creating PostgreSQL extensions..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" <<EOF
-- Create extensions in order (dependencies first)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS cube;           -- Required by earthdistance
CREATE EXTENSION IF NOT EXISTS earthdistance;  -- Depends on cube
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Verify extensions
SELECT extname, extversion FROM pg_extension ORDER BY extname;
EOF

echo "✓ Extensions created successfully"
echo "=== Extension Setup Complete ==="