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

    echo "Checking if database $DB_NAME exists..."
    
    # Check if database exists
    DB_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" || echo "0")
    
    if [ "$DB_EXISTS" = "1" ]; then
        echo "Database $DB_NAME exists. Proceeding with cleanup..."
        
        # Step 1: Terminate all connections to the database
        echo "Terminating connections to database $DB_NAME..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" \
            || echo "Warning: Failed to terminate some connections"
        
        # Step 2: Revoke connect privileges
        echo "Revoking connect privileges..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "REVOKE CONNECT ON DATABASE \"$DB_NAME\" FROM PUBLIC;" \
            || echo "Warning: Failed to revoke connect privileges"
        
        # Step 3: Transfer ownership to postgres (CRITICAL FIX)
        echo "Transferring database ownership to postgres..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "REASSIGN OWNED BY \"$DB_USER\" TO postgres;" \
            || echo "Warning: Failed to reassign ownership"
        
        # Step 4: Change database owner to postgres
        echo "Changing database owner to postgres..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "ALTER DATABASE \"$DB_NAME\" OWNER TO postgres;" \
            || echo "Warning: Database owner change failed (may already be postgres)"
        
        # Step 5: Drop all objects owned by the user in the database
        echo "Dropping objects owned by $DB_USER in database $DB_NAME..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -c \
            "DROP OWNED BY \"$DB_USER\" CASCADE;" \
            || echo "Warning: Failed to drop owned objects"
        
        # Step 6: Now drop the database
        echo "Dropping database $DB_NAME..."
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "DROP DATABASE \"$DB_NAME\";" \
            || {
                echo "ERROR: Failed to drop database $DB_NAME"
                echo "Attempting force drop..."
                psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
                    "UPDATE pg_database SET datallowconn = 'false' WHERE datname = '$DB_NAME';"
                psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
                    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME';"
                psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
                    "DROP DATABASE \"$DB_NAME\";"
            }
        
        echo "✅ Database $DB_NAME dropped successfully"
    else
        echo "Database $DB_NAME does not exist. Skipping database drop."
    fi
    
    # Step 7: Drop the user/role
    echo "Checking if user $DB_USER exists..."
    USER_EXISTS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" || echo "0")
    
    if [ "$USER_EXISTS" = "1" ]; then
        echo "Dropping user $DB_USER..."
        
        # First, revoke all privileges
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"$DB_USER\";" \
            || echo "Warning: Failed to revoke table privileges"
        
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM \"$DB_USER\";" \
            || echo "Warning: Failed to revoke sequence privileges"
        
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "REVOKE ALL PRIVILEGES ON DATABASE postgres FROM \"$DB_USER\";" \
            || echo "Warning: Failed to revoke database privileges"
        
        # Drop the role
        psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
            "DROP ROLE IF EXISTS \"$DB_USER\";" \
            || {
                echo "ERROR: Failed to drop user $DB_USER"
                echo "Checking dependencies..."
                psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c \
                    "SELECT * FROM pg_roles WHERE rolname='$DB_USER';"
            }
        
        echo "✅ User $DB_USER dropped successfully"
    else
        echo "User $DB_USER does not exist. Skipping user drop."
    fi

elif [ "$DB_TYPE" = "MYSQL" ]; then
    echo "Installing MySQL client..."
    apk update && apk add --no-cache mysql-client

    export MYSQL_PWD=$ROOT_PASSWORD

    echo "Dropping database $DB_NAME..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" \
        || echo "Warning: Failed to drop database $DB_NAME"

    echo "Dropping user $DB_USER..."
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e "DROP USER IF EXISTS '$DB_USER'@'%';" \
        || echo "Warning: Failed to drop user $DB_USER"
    
    echo "✅ MySQL cleanup complete"

else
    echo "Unsupported or None DB_TYPE: $DB_TYPE. Skipping cleanup."
    exit 0
fi

echo "=========================================="
echo "✅ Database cleanup complete!"
echo "=========================================="
