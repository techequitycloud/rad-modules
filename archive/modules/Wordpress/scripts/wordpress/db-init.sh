            set -e
            echo "Installing dependencies..."
            apk update && apk add --no-cache mysql-client netcat-openbsd

            # Use DB_IP (internal IP injected by CloudRunApp/jobs.tf) for TCP connection
            # WORDPRESS_DB_HOST points to a Unix socket path used by the Cloud Run service,
            # but the db-init job should connect via TCP to the database internal IP.
            TARGET_DB_HOST="${DB_IP:-${DB_HOST}}"
            echo "Using DB Host: $TARGET_DB_HOST"

            # Check if TARGET_DB_HOST is set
            if [ -z "$TARGET_DB_HOST" ]; then
              echo "Error: DB_HOST is not set."
              exit 1
            fi

            # DB_PASSWORD and ROOT_PASSWORD are automatically injected by CloudRunApp/jobs.tf
            if [ -z "$DB_PASSWORD" ]; then
              echo "Error: DB_PASSWORD is not set. It should be injected by CloudRunApp/jobs.tf."
              exit 1
            fi

            if [ -z "$ROOT_PASSWORD" ]; then
              echo "Error: ROOT_PASSWORD is not set. It should be injected by CloudRunApp/jobs.tf."
              exit 1
            fi

            # Check if using Unix socket or TCP
            if echo "$TARGET_DB_HOST" | grep -q "^/"; then
                echo "Using Unix socket connection."
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