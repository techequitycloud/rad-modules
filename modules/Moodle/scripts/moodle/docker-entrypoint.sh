#!/usr/bin/env bash
#
# Moodle Docker Entrypoint for Google Cloud Run
# Handles Cloud SQL connections, Moodle installation, and configuration
#

set -Eeuo pipefail

echo "=== Moodle Docker Entrypoint for Google Cloud Run ==="
echo "Moodle Version: ${MOODLE_VERSION:-unknown}"
echo "PHP Version: $(php -v | head -n 1)"

# Function to wait for database
wait_for_db() {
    echo "Waiting for database connection..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if [ "${MOODLE_DB_TYPE:-mysqli}" = "pgsql" ]; then
            if pg_isready -h "${MOODLE_DB_HOST}" -p "${MOODLE_DB_PORT:-5432}" -U "${MOODLE_DB_USER}" >/dev/null 2>&1; then
                echo "✓ PostgreSQL database is ready"
                return 0
            fi
        else
            if mysqladmin ping -h"${MOODLE_DB_HOST}" -P"${MOODLE_DB_PORT:-3306}" -u"${MOODLE_DB_USER}" -p"${MOODLE_DB_PASS}" --silent >/dev/null 2>&1; then
                echo "✓ MySQL/MariaDB database is ready"
                return 0
            fi
        fi

        echo "  Attempt $attempt/$max_attempts - Database not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo "✗ Database connection timeout after $max_attempts attempts"
    return 1
}

# Cloud SQL Socket Handling
echo "Checking for Cloud SQL socket..."
SOCKET_FILE=""

if [ -d "/cloudsql" ]; then
    echo "  Searching in /cloudsql..."
    SOCKET_FILE=$(find /cloudsql -type s -print -quit 2>/dev/null || echo "")
fi

if [ -z "$SOCKET_FILE" ] && [ -d "/var/run/mysqld" ]; then
    echo "  Searching in /var/run/mysqld..."
    SOCKET_FILE=$(find /var/run/mysqld -type s -print -quit 2>/dev/null || echo "")
fi

if [ -n "$SOCKET_FILE" ]; then
    echo "✓ Found Cloud SQL socket: $SOCKET_FILE"
    mkdir -p /tmp
    ln -sf "$SOCKET_FILE" /tmp/mysql.sock
    export MOODLE_DB_HOST="localhost:/tmp/mysql.sock"
    echo "  Using Unix socket connection"
else
    echo "⚠ No Cloud SQL socket found, using TCP connection"
    export MOODLE_DB_HOST="${MOODLE_DB_HOST:-mysql}"
fi

# Verify required environment variables
echo "Checking required environment variables..."
REQUIRED_VARS=(
    "MOODLE_DB_TYPE"
    "MOODLE_DB_HOST"
    "MOODLE_DB_NAME"
    "MOODLE_DB_USER"
    "MOODLE_DB_PASS"
    "APP_URL"
)

# Map APP_URL to MOODLE_WWW_ROOT for consistency
export MOODLE_WWW_ROOT="${APP_URL}"

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "✗ Missing required environment variable: $var"
        exit 1
    else
        if [ "$var" = "MOODLE_DB_PASS" ]; then
            echo "  ✓ $var: ********"
        else
            echo "  ✓ $var: ${!var}"
        fi
    fi
done

# Check PHP extensions
echo "Verifying PHP extensions..."
REQUIRED_EXTENSIONS=(
    "mysqli"
    "pgsql"
    "gd"
    "intl"
    "zip"
    "soap"
    "xmlrpc"
    "mbstring"
    "curl"
    "opcache"
    "redis"
)

for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if php -m | grep -qi "^$ext$"; then
        echo "  ✓ $ext"
    else
        echo "  ✗ $ext (missing)"
    fi
done

# Wait for database
if ! wait_for_db; then
    echo "✗ Cannot proceed without database connection"
    exit 1
fi

# Create moodledata directory if it doesn't exist
if [ ! -d "${MOODLE_DATA_DIR}" ]; then
    echo "Creating moodledata directory: ${MOODLE_DATA_DIR}"
    mkdir -p "${MOODLE_DATA_DIR}"
    chown -R www-data:www-data "${MOODLE_DATA_DIR}"
    chmod -R 770 "${MOODLE_DATA_DIR}"
fi

# Check if Moodle is already installed
if [ ! -f "${MOODLE_WWW_DIR}/config.php" ]; then
    echo "Moodle config.php not found - generating from template..."

    # Generate config.php from template
    if [ -f "/usr/local/share/moodle-config-template.php" ]; then
        cp /usr/local/share/moodle-config-template.php "${MOODLE_WWW_DIR}/config.php"

        # Replace placeholders with environment variables
        sed -i "s|{{MOODLE_DB_TYPE}}|${MOODLE_DB_TYPE}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DB_HOST}}|${MOODLE_DB_HOST}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DB_NAME}}|${MOODLE_DB_NAME}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DB_USER}}|${MOODLE_DB_USER}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DB_PASS}}|${MOODLE_DB_PASS}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DB_PREFIX}}|${MOODLE_DB_PREFIX:-mdl_}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_WWW_ROOT}}|${MOODLE_WWW_ROOT}|g" "${MOODLE_WWW_DIR}/config.php"
        sed -i "s|{{MOODLE_DATA_DIR}}|${MOODLE_DATA_DIR}|g" "${MOODLE_WWW_DIR}/config.php"

        # Redis configuration
        if [ -n "${REDIS_HOST:-}" ]; then
            echo "Configuring Redis session storage..."
            sed -i "s|{{REDIS_HOST}}|${REDIS_HOST}|g" "${MOODLE_WWW_DIR}/config.php"
            sed -i "s|{{REDIS_PORT}}|${REDIS_PORT:-6379}|g" "${MOODLE_WWW_DIR}/config.php"
        fi

        chown www-data:www-data "${MOODLE_WWW_DIR}/config.php"
        chmod 640 "${MOODLE_WWW_DIR}/config.php"
        echo "✓ config.php generated successfully"
    else
        echo "✗ Template config.php not found!"
        exit 1
    fi

    # Check if database is empty (new installation)
    echo "Checking if Moodle database is initialized..."
    if [ "${MOODLE_DB_TYPE}" = "pgsql" ]; then
        TABLE_COUNT=$(PGPASSWORD="${MOODLE_DB_PASS}" psql -h "${MOODLE_DB_HOST}" -U "${MOODLE_DB_USER}" -d "${MOODLE_DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '${MOODLE_DB_PREFIX:-mdl_}%';" 2>/dev/null || echo "0")
    else
        TABLE_COUNT=$(mysql -h"${MOODLE_DB_HOST}" -u"${MOODLE_DB_USER}" -p"${MOODLE_DB_PASS}" -D"${MOODLE_DB_NAME}" -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${MOODLE_DB_NAME}' AND table_name LIKE '${MOODLE_DB_PREFIX:-mdl_}%';" 2>/dev/null || echo "0")
    fi

    if [ "$TABLE_COUNT" -eq 0 ]; then
        echo "Empty database detected - running Moodle CLI installation..."

        # Run Moodle CLI installer
        sudo -u www-data php "${MOODLE_WWW_DIR}/admin/cli/install.php" \
            --lang="${MOODLE_LANG:-en}" \
            --wwwroot="${MOODLE_WWW_ROOT}" \
            --dataroot="${MOODLE_DATA_DIR}" \
            --dbtype="${MOODLE_DB_TYPE}" \
            --dbhost="${MOODLE_DB_HOST}" \
            --dbname="${MOODLE_DB_NAME}" \
            --dbuser="${MOODLE_DB_USER}" \
            --dbpass="${MOODLE_DB_PASS}" \
            --prefix="${MOODLE_DB_PREFIX:-mdl_}" \
            --fullname="${MOODLE_SITE_FULLNAME:-Moodle LMS}" \
            --shortname="${MOODLE_SITE_SHORTNAME:-Moodle}" \
            --adminuser="${MOODLE_ADMIN_USER:-admin}" \
            --adminpass="${MOODLE_ADMIN_PASS:-Admin@123}" \
            --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
            --non-interactive \
            --agree-license

        if [ $? -eq 0 ]; then
            echo "✓ Moodle installation completed successfully"
        else
            echo "✗ Moodle installation failed"
            exit 1
        fi
    else
        echo "✓ Moodle database already initialized ($TABLE_COUNT tables found)"
    fi
else
    echo "✓ Moodle config.php already exists"

    # Run upgrade if needed
    echo "Checking for pending Moodle upgrades..."
    if sudo -u www-data php "${MOODLE_WWW_DIR}/admin/cli/upgrade.php" --non-interactive 2>&1 | grep -q "Moodle upgrade pending"; then
        echo "Running Moodle upgrade..."
        sudo -u www-data php "${MOODLE_WWW_DIR}/admin/cli/upgrade.php" --non-interactive
        echo "✓ Moodle upgrade completed"
    else
        echo "✓ No upgrades needed"
    fi
fi

# Purge caches
echo "Purging Moodle caches..."
sudo -u www-data php "${MOODLE_WWW_DIR}/admin/cli/purge_caches.php" || echo "⚠ Cache purge failed (non-critical)"

# Start cron in background
echo "Starting Moodle cron service..."
service cron start
echo "✓ Cron service started"

# Fix permissions
echo "Verifying file permissions..."
chown -R www-data:www-data "${MOODLE_WWW_DIR}" "${MOODLE_DATA_DIR}"
find "${MOODLE_WWW_DIR}" -type d -exec chmod 755 {} \;
find "${MOODLE_WWW_DIR}" -type f -exec chmod 644 {} \;
chmod -R 770 "${MOODLE_DATA_DIR}"
echo "✓ Permissions verified"

echo "=== Moodle initialization complete ==="
echo "Starting Apache on port ${PORT:-80}..."

# Adjust Apache Port
sed -i "s/80/${PORT:-80}/g" /etc/apache2/ports.conf /etc/apache2/sites-enabled/*.conf

# Execute the main command
exec "$@"
