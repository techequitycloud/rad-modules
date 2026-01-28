#!/bin/sh
set -e

# Logic to handle Cloud Run Unix socket connections
if echo "$MYSQL_HOST" | grep -q "^/"; then
    echo "Detected Unix socket in MYSQL_HOST: $MYSQL_HOST"
    
    # Identify PHP INI location (Alpine/OpenEMR specific)
    # Search common locations
    PHP_INI_FILE=""
    for loc in /etc/php83/php.ini /etc/php82/php.ini /etc/php81/php.ini /etc/php8/php.ini; do
        if [ -f "$loc" ]; then
            PHP_INI_FILE="$loc"
            break
        fi
    done
    
    if [ -n "$PHP_INI_FILE" ]; then
        echo "Updating default_socket in $PHP_INI_FILE..."
        
        # Handle mysqli.default_socket
        if grep -q "^;*mysqli.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*mysqli.default_socket.*|mysqli.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
        else
            echo "mysqli.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
        fi

        # Handle pdo_mysql.default_socket
        if grep -q "^;*pdo_mysql.default_socket" "$PHP_INI_FILE"; then
            sed -i "s|^;*pdo_mysql.default_socket.*|pdo_mysql.default_socket = $MYSQL_HOST|" "$PHP_INI_FILE"
        else
            echo "pdo_mysql.default_socket = $MYSQL_HOST" >> "$PHP_INI_FILE"
        fi
    else
        echo "Warning: php.ini not found. Socket configuration might fail."
    fi

    # Force MYSQL_HOST to localhost so applications use the default socket
    export MYSQL_HOST="localhost"
    export DB_HOST="localhost"
fi

# Execute original entrypoint
# We assume the base image uses the standard OpenEMR entrypoint script.
# If arguments are passed, run them; otherwise run the default command.
if [ "$#" -eq 0 ]; then
    exec /sbin/tini -- /var/www/localhost/htdocs/openemr/contrib/util/docker-entrypoint.sh
else
    exec "$@"
fi
