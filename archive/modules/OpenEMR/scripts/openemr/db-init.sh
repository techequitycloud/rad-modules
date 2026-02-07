            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use DB_IP if available, else DB_HOST.
            TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Check if using Unix socket or TCP
            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "Using Unix socket connection."
                # Verify socket existence (optional, or just retry connection)
            else
                echo "Using TCP connection."
                echo "Waiting for database..."
                until nc -z $TARGET_DB_HOST 3306; do
                  echo "Waiting for MySQL port 3306..."
                  sleep 2
                done
            fi

            cat > ~/.my.cnf << EOF
[client]
user=root
password=${ROOT_PASSWORD}
EOF

            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "socket=$TARGET_DB_HOST" >> ~/.my.cnf
            else
                echo "host=$TARGET_DB_HOST" >> ~/.my.cnf
            fi

            chmod 600 ~/.my.cnf

            echo "Creating User ${DB_USER} if not exists..."
            mysql --defaults-file=~/.my.cnf <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF

            echo "Creating Database ${DB_NAME} if not exists..."
            mysql --defaults-file=~/.my.cnf -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"

            echo "Granting privileges..."
            mysql --defaults-file=~/.my.cnf <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

            rm -f ~/.my.cnf
            echo "DB Init complete."