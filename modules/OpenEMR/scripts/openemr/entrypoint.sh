#!/bin/sh
set -e

echo "================================================"
echo "Starting OpenEMR with Cloud Run Configuration"
echo "================================================"

# Debug: Show current environment
echo "Environment:"
echo "  MYSQL_HOST: ${MYSQL_HOST:-not set}"
echo "  MYSQL_USER: ${MYSQL_USER:-not set}"
echo "  MYSQL_DATABASE: ${MYSQL_DATABASE:-not set}"
echo "  DB_HOST: ${DB_HOST:-not set}"
echo ""

# Logic to handle Cloud Run Unix socket connections
if [ -n "$MYSQL_HOST" ] && echo "$MYSQL_HOST" | grep -q "^/"; then
    echo "✓ Detected Unix socket in MYSQL_HOST: $MYSQL_HOST"
    
    # Find PHP INI file
    PHP_INI_FILE=""
    for loc in /etc/php84/php.ini /etc/php83/php.ini /etc/php82/php.ini /etc/php81/php.ini /etc/php8/php.ini /usr/local/etc/php/php.ini; do
        if [ -f "$loc" ]; then
            PHP_INI_FILE="$loc"
            echo "✓ Found PHP INI: $PHP_INI_FILE"
            break
        fi
    done
    
    if [ -n "$PHP_INI_FILE" ]; then
        echo "Configuring PHP for Unix socket..."
        
        # Backup original (ignore errors if already exists)
        cp "$PHP_INI_FILE" "${PHP_INI_FILE}.backup" 2>/dev/null || true
        
        # Configure mysqli
        if grep -q "^;*mysqli.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*mysqli.default_socket.*|mysqli.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
            echo "  ✓ Updated mysqli.default_socket"
        else
            echo "mysqli.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
            echo "  ✓ Added mysqli.default_socket"
        fi

        # Configure PDO MySQL
        if grep -q "^;*pdo_mysql.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*pdo_mysql.default_socket.*|pdo_mysql.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
            echo "  ✓ Updated pdo_mysql.default_socket"
        else
            echo "pdo_mysql.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
            echo "  ✓ Added pdo_mysql.default_socket"
        fi
        
        # Verify configuration
        echo ""
        echo "Current PHP socket configuration:"
        grep -E "mysqli.default_socket|pdo_mysql.default_socket" "$PHP_INI_FILE" || echo "  (no socket config found)"
        echo ""
    else
        echo "⚠ Warning: php.ini not found. Socket configuration might fail."
        echo "  Searched locations:"
        echo "    - /etc/php83/php.ini"
        echo "    - /etc/php82/php.ini"
        echo "    - /etc/php81/php.ini"
        echo "    - /etc/php8/php.ini"
        echo "    - /usr/local/etc/php/php.ini"
        echo ""
    fi

    # Set environment variables for localhost
    export MYSQL_HOST="localhost"
    export DB_HOST="localhost"
    echo "✓ Environment configured for localhost connection"
    echo ""
fi

# Check if sqlconf.php exists and needs updating
SQLCONF="/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php"
if [ -f "$SQLCONF" ]; then
    # Check for corruption: missing $host variable indicates broken sqlconf.php from prior deploy
    if ! grep -q '$host' "$SQLCONF" 2>/dev/null; then
        echo "⚠ Existing sqlconf.php is corrupted, recreating..."
        rm -f "$SQLCONF"
    fi
fi

if [ -f "$SQLCONF" ]; then
    echo "Found existing sqlconf.php, updating database connection..."

    # Backup
    cp "$SQLCONF" "${SQLCONF}.backup" 2>/dev/null || true

    # Update database connection settings
    if [ -n "$MYSQL_USER" ]; then
        sed -i "s/\$host\s*=\s*'[^']*'/\$host = '${DB_HOST:-localhost}'/" "$SQLCONF" 2>/dev/null || true
        sed -i "s/\$login\s*=\s*'[^']*'/\$login = '${MYSQL_USER}'/" "$SQLCONF" 2>/dev/null || true
        sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '${MYSQL_PASS:-${MYSQL_PASSWORD}}'/" "$SQLCONF" 2>/dev/null || true
        sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '${MYSQL_DATABASE}'/" "$SQLCONF" 2>/dev/null || true
        echo "✓ Database configuration updated"
    fi
    echo ""
else
    echo "ℹ sqlconf.php not found. Creating default configuration..."
    # Ensure the directory structure exists
    mkdir -p "$(dirname "$SQLCONF")"
    chown 1000:1000 "$(dirname "$SQLCONF")"

    # Create sqlconf.php with current environment variables
    cat > "$SQLCONF" <<SQLEOF
<?php
//  OpenEMR
//  MySQL Config

\$host	= '${DB_HOST:-localhost}';
\$port	= '3306';
\$login	= '${MYSQL_USER}';
\$pass	= '${MYSQL_PASS:-${MYSQL_PASSWORD}}';
\$dbase	= '${MYSQL_DATABASE}';

\$rootpass	= '${MYSQL_ROOT_PASS:-${ROOT_PASSWORD}}';

//Added by OpenEMR Configuration:
\$config = 1;
SQLEOF

    chown 1000:1000 "$SQLCONF"
    chmod 600 "$SQLCONF"
    echo "✓ Created sqlconf.php with database configuration"
    echo ""
fi

echo "================================================"
echo "Starting OpenEMR Application..."
echo "================================================"
echo ""

# Change to the correct working directory
cd /var/www/localhost/htdocs/openemr || {
    echo "Error: Cannot change to OpenEMR directory"
    exit 1
}

# Execute the original command or passed arguments
if [ "$#" -eq 0 ]; then
    # No arguments passed, use default command
    echo "Executing: ./openemr.sh"
    exec ./openemr.sh
else
    # Arguments passed, execute them
    echo "Executing: $@"
    exec "$@"
fi
