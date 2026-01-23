#!/bin/bash
set -e

# Inputs from Environment Variables
# DB_TYPE: POSTGRES or MYSQL
# DB_HOST
# DB_PORT
# DB_NAME
# DB_USER
# ROOT_PASSWORD (from secret)

echo "Starting Database Cleanup..."
echo "DB Type: $DB_TYPE"
echo "DB Host: $DB_HOST"
echo "DB Name: $DB_NAME"
echo "DB User: $DB_USER"

if [ "$DB_TYPE" = "POSTGRES" ]; then
    echo "Installing PostgreSQL client..."
    apk update && apk add --no-cache postgresql-client

    export PGPASSWORD=$ROOT_PASSWORD

    echo "Terminating connections to database $DB_NAME..."
    # We must handle the case where the DB doesn't exist
    if psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME';" || echo "Warning: Failed to terminate connections"

        echo "Dropping database $DB_NAME..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c "DROP DATABASE \"$DB_NAME\";"
    else
        echo "Database $DB_NAME does not exist."
    fi

    echo "Dropping user $DB_USER..."
    # Check if user exists (optional, DROP IF EXISTS works)
    psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c "DROP ROLE IF EXISTS \"$DB_USER\";"

elif [ "$DB_TYPE" = "MYSQL" ]; then
    echo "Installing MySQL client..."
    apk update && apk add --no-cache mysql-client

    export MYSQL_PWD=$ROOT_PASSWORD

    echo "Dropping database $DB_NAME..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"

    echo "Dropping user $DB_USER..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e "DROP USER IF EXISTS '$DB_USER'@'%';"
else
    echo "Unsupported or None DB_TYPE: $DB_TYPE. Skipping cleanup."
    exit 0
fi

echo "Database cleanup complete."
