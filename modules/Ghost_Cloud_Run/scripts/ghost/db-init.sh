            set -e

            echo "=========================================="
            echo "Ghost 6.10.3 Database Initialization"
            echo "MySQL 8.0 Configuration"
            echo "=========================================="

            # Use DB_IP (private IP) instead of 127.0.0.1
            TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
            echo "Target DB Host: $TARGET_DB_HOST"

            # Validate required variables
            if [ -z "$DB_PASSWORD" ]; then
              echo "ERROR: DB_PASSWORD is not set"
              exit 1
            fi

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "ERROR: ROOT_PASSWORD is not set"
              exit 1
            fi

            # Wait for database to be ready
            echo "Waiting for MySQL at $TARGET_DB_HOST:3306..."
            MAX_RETRIES=30
            RETRY_COUNT=0

            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
              if mysqladmin ping -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD --silent 2>/dev/null; then
                echo "✓ MySQL is ready"
                break
              fi
              RETRY_COUNT=$((RETRY_COUNT + 1))
              echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
              sleep 2
            done

            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
              echo "ERROR: Could not connect to MySQL after $MAX_RETRIES attempts"
              exit 1
            fi

            # Test root connection
            echo "Testing root connection..."
            if ! mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD -e "SELECT VERSION();" > /dev/null 2>&1; then
              echo "ERROR: Could not connect as root user"
              exit 1
            fi

            # Get MySQL version
            MYSQL_VERSION=$(mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD -sN -e "SELECT VERSION();")
            echo "✓ Connected to MySQL $MYSQL_VERSION"

            # ✅ Create database with Ghost 6.x requirements
            echo "Creating database '$DB_NAME' with utf8mb4..."
            mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD <<EOF
-- Create database with proper character set for Ghost 6.x
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;  -- MySQL 8.0 default collation

-- Set database-level settings for Ghost 6.x
ALTER DATABASE \`$DB_NAME\`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
EOF

            echo "✓ Database created"

            # ✅ Create user with MySQL 8.0 authentication
            echo "Creating user '$DB_USER' with caching_sha2_password..."
            mysql -h $TARGET_DB_HOST -u root -p$ROOT_PASSWORD <<EOF
-- Drop user if exists (for idempotency)
DROP USER IF EXISTS '$DB_USER'@'%';

-- Create user with MySQL 8.0 native authentication
-- Ghost 6.x supports caching_sha2_password
CREATE USER '$DB_USER'@'%'
  IDENTIFIED WITH caching_sha2_password BY '$DB_PASSWORD';

-- Grant all privileges on Ghost database
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';

-- Grant necessary global privileges for Ghost migrations
GRANT CREATE, ALTER, DROP, INDEX, REFERENCES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';

-- Apply changes
FLUSH PRIVILEGES;
EOF

            echo "✓ User created with privileges"

            # ✅ Set MySQL 8.0 specific settings for Ghost 6.x
            echo "Configuring MySQL settings for Ghost 6.x..."
            echo "Skipping global MySQL settings configuration (handled by Cloud SQL flags)"

            # Verify user can connect
            echo "Verifying user connection..."
            if mysql -h $TARGET_DB_HOST -u $DB_USER -p$DB_PASSWORD -e "USE \`$DB_NAME\`; SELECT 1;" > /dev/null 2>&1; then
              echo "✓ User connection verified"
            else
              echo "ERROR: User cannot connect to database"
              exit 1
            fi

            # ✅ Display database info
            echo ""
            echo "Database Information:"
            mysql -h $TARGET_DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "
              SELECT
                @@character_set_database as charset,
                @@collation_database as collation,
                @@version as mysql_version;
            "

            echo ""
            echo "=========================================="
            echo "✓ Ghost 6.10.3 database initialization complete"
            echo "=========================================="