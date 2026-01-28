#!/bin/sh
set -e

echo "================================================"
echo "Starting OpenEMR with Cloud Run Configuration"
echo "================================================"

# Logic to handle Cloud Run Unix socket connections
if echo "$MYSQL_HOST" | grep -q "^/"; then
    echo "Detected Unix socket in MYSQL_HOST: $MYSQL_HOST"
    
    # Find PHP INI file
    PHP_INI_FILE=""

    # Try dynamic detection first
    DETECTED_INI=$(php --ini 2>/dev/null | grep "Loaded Configuration File" | sed 's/.*: *//')
    if [ -n "$DETECTED_INI" ] && [ -f "$DETECTED_INI" ]; then
        PHP_INI_FILE="$DETECTED_INI"
        echo "Found PHP INI (via php --ini): $PHP_INI_FILE"
    else
        # Fallback to hardcoded paths
        for loc in /etc/php84/php.ini /etc/php83/php.ini /etc/php82/php.ini /etc/php81/php.ini /etc/php8/php.ini /usr/local/etc/php/php.ini; do
            if [ -f "$loc" ]; then
                PHP_INI_FILE="$loc"
                echo "Found PHP INI (via search): $PHP_INI_FILE"
                break
            fi
        done
    fi
    
    if [ -n "$PHP_INI_FILE" ]; then
        echo "Configuring PHP for Unix socket..."
        
        # Backup original
        cp "$PHP_INI_FILE" "${PHP_INI_FILE}.backup" 2>/dev/null || true
        
        # Configure mysqli
        if grep -q "^;*mysqli.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*mysqli.default_socket.*|mysqli.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
        else
            echo "mysqli.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
        fi

        # Configure PDO MySQL
        if grep -q "^;*pdo_mysql.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*pdo_mysql.default_socket.*|pdo_mysql.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
        else
            echo "pdo_mysql.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
        fi
        
        echo "✓ PHP configured for Unix socket"
    else
        echo "⚠ Warning: php.ini not found. Socket configuration might fail."
    fi

    # Set environment variables for localhost
    export MYSQL_HOST="localhost"
    export DB_HOST="localhost"
    echo "✓ Environment configured for localhost connection"
fi

# Check if sqlconf.php exists and needs updating
SQLCONF="/var/www/localhost/htdocs/openemr/sites/default/sqlconf.php"
if [ -f "$SQLCONF" ]; then
    echo "Found existing sqlconf.php, updating database connection..."
    
    # Update database connection settings
    sed -i "s/\$host\s*=\s*'[^']*'/\$host = '${DB_HOST:-localhost}'/" "$SQLCONF" 2>/dev/null || true
    sed -i "s/\$login\s*=\s*'[^']*'/\$login = '${MYSQL_USER}'/" "$SQLCONF" 2>/dev/null || true
    sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '${MYSQL_PASSWORD}'/" "$SQLCONF" 2>/dev/null || true
    sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '${MYSQL_DATABASE}'/" "$SQLCONF" 2>/dev/null || true
    
    echo "✓ Database configuration updated"
fi

echo "================================================"
echo "Starting OpenEMR Application..."
echo "================================================"

# Change to the correct working directory
cd /var/www/localhost/htdocs/openemr

# Execute the original command
if [ "$#" -eq 0 ]; then
    # No arguments passed, use default command
    exec ./openemr.sh
else
    # Arguments passed, execute them
    exec "$@"
fi
