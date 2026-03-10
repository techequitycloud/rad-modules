set -e
echo "=== Cyclos User Setup ==="

# Install PostgreSQL client
apk update && apk add --no-cache postgresql-client

# Use DB_IP if available
TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
echo "Using DB Host: $TARGET_DB_HOST"

# Wait for database
export PGPASSWORD=$ROOT_PASSWORD
until psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
  echo "Waiting for database..."
  sleep 2
done

# Create Cyclos user
echo "Creating user $DB_USER..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD';
    RAISE NOTICE 'User created';
  ELSE
    ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
    RAISE NOTICE 'User password updated';
  END IF;
END
\$\$;

-- Grant necessary privileges
ALTER ROLE "$DB_USER" CREATEDB;
ALTER ROLE "$DB_USER" INHERIT;
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
GRANT "$DB_USER" TO postgres;
EOF

# Grant schema and extension privileges
echo "Granting schema privileges..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d "$DB_NAME" <<EOF
GRANT ALL ON SCHEMA public TO "$DB_USER";
GRANT ALL ON ALL TABLES IN SCHEMA public TO "$DB_USER";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO "$DB_USER";

-- Grant usage on extensions
GRANT USAGE ON SCHEMA public TO "$DB_USER";

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "$DB_USER";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO "$DB_USER";
EOF

# Change database owner to cyclos user
echo "Setting database owner..."
psql -h "$TARGET_DB_HOST" -p 5432 -U postgres -d postgres -c "ALTER DATABASE \"$DB_NAME\" OWNER TO \"$DB_USER\";"

echo "✓ User setup complete"
echo "=== User Setup Complete ==="