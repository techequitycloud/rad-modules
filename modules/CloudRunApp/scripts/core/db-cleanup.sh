#!/bin/bash
# Copyright 2024 Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

set -e

# Function to retry commands with exponential backoff
retry_cmd() {
    local max_attempts=5
    local attempt=1
    local delay=2

    while [ $attempt -le $max_attempts ]; do
        "$@" && return 0

        echo "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
        sleep $delay

        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done

    echo "Command failed after $max_attempts attempts."
    return 1
}

echo "=========================================="
echo "Starting Database Cleanup"
echo "=========================================="
echo "DB Type: $DB_TYPE"
echo "DB Host: $DB_HOST"
echo "DB Port: ${DB_PORT:-5432}"
echo "DB Name: $DB_NAME"
echo "DB User: $DB_USER"
echo "=========================================="

if [ "$DB_TYPE" = "POSTGRES" ]; then
    echo "Installing PostgreSQL client..."
    # Retry apk update and add to handle transient network issues
    if ! retry_cmd apk update; then
        echo "⚠ Warning: apk update failed, trying to install anyway..."
    fi

    retry_cmd apk add --no-cache postgresql-client netcat-openbsd || {
        echo "❌ ERROR: Failed to install required packages."
        exit 1
    }

    # Connectivity check
    echo "Testing connectivity to $DB_HOST:$DB_PORT..."
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -zv "$DB_HOST" "${DB_PORT:-5432}"; then
            echo "✅ Connectivity check passed."
        else
            echo "❌ ERROR: Cannot reach $DB_HOST:${DB_PORT:-5432}"
            # Don't exit here, let psql try and fail with more info
        fi
    fi

    export PGPASSWORD=$ROOT_PASSWORD
    export PGCONNECT_TIMEOUT=10

    echo "Checking if database $DB_NAME exists..."
    
    # Check if database exists - Explicitly handle errors
    # Removed 2>/dev/null to see errors in logs
    # Added -w to prevent password prompt hangs
    DB_EXISTS=$(psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" -w || echo "ERROR")
    
    if [ "$DB_EXISTS" = "ERROR" ]; then
        echo "❌ ERROR: Failed to check for database existence. Check logs above for details."
        # We don't exit here immediately to allow user cleanup attempt, but usually this is fatal.
        exit 1
    fi

    if [ "$DB_EXISTS" = "1" ]; then
        echo "✅ Database $DB_NAME exists. Proceeding with cleanup..."
        
        # Step 1: Terminate all connections
        echo "Terminating connections to database $DB_NAME..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -w <<EOF
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = '$DB_NAME' 
  AND pid <> pg_backend_pid();
EOF
        
        # Step 2: Grant role to postgres first
        echo "Granting role $DB_USER to postgres (required for reassignment)..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "GRANT \"$DB_USER\" TO postgres;" -w \
            2>/dev/null || echo "⚠️  Warning: Role grant failed (may already be granted)"

        # Step 3: Revoke connect privileges
        echo "Revoking connect privileges..."
        # Explicitly grant connect to postgres first to ensure we don't lock ourselves out when revoking PUBLIC
        echo "Explicitly granting CONNECT to postgres..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "GRANT CONNECT ON DATABASE \"$DB_NAME\" TO postgres; REVOKE CONNECT ON DATABASE \"$DB_NAME\" FROM PUBLIC, \"$DB_USER\";" -w \
            2>/dev/null || echo "⚠️  Warning: Failed to revoke connect privileges (may not exist)"
        
        # Step 4: Connect to the database and reassign ownership
        echo "Reassigning ownership of objects in database $DB_NAME..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d "$DB_NAME" -w <<EOF
-- Reassign all objects owned by the user to postgres
REASSIGN OWNED BY "$DB_USER" TO postgres;

-- Drop any remaining objects owned by the user
DROP OWNED BY "$DB_USER" CASCADE;
EOF
        
        # Step 5: Change database owner
        echo "Changing database owner to postgres..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "ALTER DATABASE \"$DB_NAME\" OWNER TO postgres;" -w \
            2>/dev/null || echo "⚠️  Warning: Database owner change failed (may already be postgres)"
        
        # Step 6: Disconnect again and drop the database
        echo "Final connection termination..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -w <<EOF
-- Disallow new connections
UPDATE pg_database SET datallowconn = 'false' WHERE datname = '$DB_NAME';

-- Terminate all connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = '$DB_NAME';
EOF
        
        # Wait a moment for connections to close
        sleep 2
        
        # Step 7: Drop the database
        echo "Dropping database $DB_NAME..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "DROP DATABASE IF EXISTS \"$DB_NAME\";" -w || {
                echo "❌ ERROR: Failed to drop database $DB_NAME"
                echo "Checking for blocking connections..."
                psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
                    "SELECT pid, usename, application_name, state FROM pg_stat_activity WHERE datname = '$DB_NAME';" -w
                exit 1
            }
        
        echo "✅ Database $DB_NAME dropped successfully"
    else
        echo "ℹ️  Database $DB_NAME does not exist. Skipping database drop."
    fi
    
    # Step 8: Drop the user/role
    echo ""
    echo "Checking if user $DB_USER exists..."
    USER_EXISTS=$(psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" -w 2>/dev/null || echo "0")
    
    if [ "$USER_EXISTS" = "1" ]; then
        echo "✅ User $DB_USER exists. Proceeding with user cleanup..."
        
        # Revoke all privileges from all databases
        echo "Revoking privileges from all databases..."
        for db in $(psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -tAc \
            "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" -w); do
            echo "  - Revoking privileges on database: $db"
            psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
                "REVOKE ALL PRIVILEGES ON DATABASE \"$db\" FROM \"$DB_USER\";" -w \
                2>/dev/null || true
        done
        
        # Revoke privileges on postgres database
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "REVOKE ALL PRIVILEGES ON DATABASE postgres FROM \"$DB_USER\";" -w \
            2>/dev/null || true
        
        # Revoke role from postgres (cleanup)
        echo "Revoking role $DB_USER from postgres..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "REVOKE \"$DB_USER\" FROM postgres;" -w \
            2>/dev/null || true
        
        # Drop the role
        echo "Dropping role $DB_USER..."
        psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -c \
            "DROP ROLE IF EXISTS \"$DB_USER\";" -w || {
                echo "❌ ERROR: Failed to drop user $DB_USER"
                echo "Checking role dependencies..."
                psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U postgres -d postgres -w <<EOF
-- Show role information
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles 
WHERE rolname='$DB_USER';

-- Show objects owned by the role
SELECT n.nspname, c.relname, c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_roles r ON r.oid = c.relowner
WHERE r.rolname = '$DB_USER'
LIMIT 10;

-- Show role memberships
SELECT r.rolname, m.rolname as member_of
FROM pg_roles r
JOIN pg_auth_members am ON r.oid = am.member
JOIN pg_roles m ON m.oid = am.roleid
WHERE r.rolname = '$DB_USER';
EOF
                exit 1
            }
        
        echo "✅ User $DB_USER dropped successfully"
    else
        echo "ℹ️  User $DB_USER does not exist. Skipping user drop."
    fi

elif [ "$DB_TYPE" = "MYSQL" ]; then
    echo "Installing MySQL client..."
    # Retry apk update and add
    if ! retry_cmd apk update; then
        echo "⚠ Warning: apk update failed, trying to install anyway..."
    fi

    retry_cmd apk add --no-cache mysql-client netcat-openbsd || {
        echo "❌ ERROR: Failed to install required packages."
        exit 1
    }

    # Connectivity check
    echo "Testing connectivity to $DB_HOST:$DB_PORT..."
    if timeout 5 nc -zv "$DB_HOST" "${DB_PORT:-3306}"; then
        echo "✅ Connectivity check passed."
    else
        echo "❌ ERROR: Cannot reach $DB_HOST:${DB_PORT:-3306}"
    fi

    export MYSQL_PWD=$ROOT_PASSWORD

    echo "Dropping database $DB_NAME..."
    mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u root -e \
        "DROP DATABASE IF EXISTS \`$DB_NAME\`;" || {
            echo "❌ ERROR: Failed to drop database $DB_NAME"
            exit 1
        }
    echo "✅ Database dropped"

    echo "Dropping user $DB_USER..."
    mysql -h "$DB_HOST" -P "${DB_PORT:-3306}" -u root -e \
        "DROP USER IF EXISTS '$DB_USER'@'%';" || {
            echo "❌ ERROR: Failed to drop user $DB_USER"
            exit 1
        }
    echo "✅ User dropped"

else
    echo "ℹ️  Unsupported or None DB_TYPE: $DB_TYPE. Skipping cleanup."
    exit 0
fi

echo ""
echo "=========================================="
echo "✅ Database cleanup complete!"
echo "=========================================="
