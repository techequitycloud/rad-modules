#!/bin/sh
# Copyright 2024 (c) Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "=== DB Import/Setup Job ==="

# Install dependencies
echo "Installing dependencies..."
apk update
apk add --no-cache mariadb-client python3 py3-pip unzip curl git \
    php83 php83-mysqli php83-pdo_mysql php83-json php83-openssl php83-curl php83-zip \
    php83-tokenizer php83-xml php83-mbstring php83-phar php83-iconv \
    php83-dom php83-simplexml php83-sodium php83-gd php83-xmlreader php83-xmlwriter php83-ctype \
    php83-soap php83-fileinfo

# Create symlink for php
ln -sf /usr/bin/php83 /usr/bin/php

# Install composer
curl -sS https://getcomposer.org/installer | php83 -- --install-dir=/usr/bin --filename=composer

# Install gdown in venv
echo "Installing gdown..."
python3 -m venv /venv
. /venv/bin/activate
pip install gdown

# Verify vars
echo "DB_HOST: $DB_HOST"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"
echo "BACKUP_FILEID: $BACKUP_FILEID"

# DB Connection Config using root
cat > /tmp/root.cnf << 'EOFCNF'
[client]
user=root
password=${ROOT_PASS}
host=${DB_HOST}
EOFCNF

# Replace variables in the config file
sed -i "s/\${ROOT_PASS}/${ROOT_PASS}/g" /tmp/root.cnf
sed -i "s/\${DB_HOST}/${DB_HOST}/g" /tmp/root.cnf
chmod 600 /tmp/root.cnf

echo "Checking DB connection..."
mysql --defaults-file=/tmp/root.cnf -e 'STATUS;' || { echo "DB Connection Failed"; exit 1; }

echo "Displaying databases..."
mysql --defaults-file=/tmp/root.cnf -e 'SHOW DATABASES;'

# Create/Update User
echo "Creating/updating user ${DB_USER}..."
mysql --defaults-file=/tmp/root.cnf -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
mysql --defaults-file=/tmp/root.cnf -e "ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
mysql --defaults-file=/tmp/root.cnf -e "FLUSH PRIVILEGES;"

# Create DB
echo "Creating database ${DB_NAME}..."
mysql --defaults-file=/tmp/root.cnf -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Grant Privileges
echo "Granting privileges..."
mysql --defaults-file=/tmp/root.cnf -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
mysql --defaults-file=/tmp/root.cnf -e "GRANT GRANT OPTION ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
mysql --defaults-file=/tmp/root.cnf -e "FLUSH PRIVILEGES;"

echo "Privileges granted."

# Backup Restore
if [ -n "${BACKUP_FILEID}" ]; then
    echo "Attempting to download backup..."

    if gdown "${BACKUP_FILEID}" -O "${DB_NAME}.zip"; then
        echo "Backup file downloaded successfully"

        # Drop DB before restore (to be clean)
        echo "Dropping database for restore..."
        mysql --defaults-file=/tmp/root.cnf -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
        mysql --defaults-file=/tmp/root.cnf -e "CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

        # Grant again
        mysql --defaults-file=/tmp/root.cnf -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
        mysql --defaults-file=/tmp/root.cnf -e "GRANT GRANT OPTION ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
        mysql --defaults-file=/tmp/root.cnf -e "FLUSH PRIVILEGES;"

        echo "Unzipping..."
        mkdir -p "${DB_NAME}"
        unzip -o "${DB_NAME}.zip" -d "${DB_NAME}"

        echo "Restoring..."
        mysql --defaults-file=/tmp/root.cnf "${DB_NAME}" < "${DB_NAME}/dump.sql"

        echo "Database restored successfully."

        # Cleanup
        rm -rf "${DB_NAME}" "${DB_NAME}.zip"
    else
        echo "Failed to download backup."
        exit 1
    fi
else
    echo "No backup file provided. Initializing database from SQL files..."

    # Clone OpenEMR repository
    echo "Cloning OpenEMR repository..."
    VERSION_TAG="rel-$(echo ${APP_VERSION} | tr -d '.')"

    cd /tmp
    git clone https://github.com/openemr/openemr.git --branch ${VERSION_TAG} --depth 1
    cd openemr

    # Install PHP dependencies
    echo "Installing composer dependencies..."
    composer install --no-dev --no-interaction --optimize-autoloader

    # List available files
    echo "Available files in openemr directory:"
    ls -la

    echo "Available SQL files:"
    ls -la sql/

    # Import database schema directly with relaxed SQL mode
    echo "Importing database schema..."
    
    # Create a temporary SQL file with relaxed mode
    cat > /tmp/import_db.sql << 'EOFSQL'
SET SESSION sql_mode = 'ALLOW_INVALID_DATES,NO_ENGINE_SUBSTITUTION';
SET FOREIGN_KEY_CHECKS = 0;
EOFSQL

    # Append the main database.sql
    cat sql/database.sql >> /tmp/import_db.sql
    
    echo "SET FOREIGN_KEY_CHECKS = 1;" >> /tmp/import_db.sql

    # Import the combined SQL
    echo "Executing database import..."
    mysql --defaults-file=/tmp/root.cnf "${DB_NAME}" < /tmp/import_db.sql

    # Create default admin user with hashed password
    echo "Creating default admin user..."
    ADMIN_PASS="${ADMIN_PASS:-pass}"
    
    # Use PHP to generate password hash
    ADMIN_PASS_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_DEFAULT);")
    
    mysql --defaults-file=/tmp/root.cnf "${DB_NAME}" <<EOFADMIN
INSERT INTO users (
    username, password, authorized, info, source, 
    fname, lname, federaltaxid, active, calendar, cal_ui
) VALUES (
    'admin', '${ADMIN_PASS_HASH}', 1, NULL, NULL,
    'Administrator', 'Administrator', '', 1, 1, 3
) ON DUPLICATE KEY UPDATE 
    password='${ADMIN_PASS_HASH}',
    active=1;
EOFADMIN

    # Set initial globals/configuration
    echo "Setting initial configuration..."
    mysql --defaults-file=/tmp/root.cnf "${DB_NAME}" <<EOFGLOBALS
INSERT INTO globals (gl_name, gl_value) VALUES
    ('language_default', 'English (Standard)'),
    ('date_display_format', '1'),
    ('time_display_format', '0'),
    ('gbl_pt_list_page_size', '20'),
    ('gbl_pt_list_new_window', '0'),
    ('default_top_pane', 'main_info.php'),
    ('encounter_page_size', '25'),
    ('gbl_pt_list_show_phone', '1')
ON DUPLICATE KEY UPDATE gl_value=VALUES(gl_value);
EOFGLOBALS

    # Import additional SQL files if needed
    echo "Checking for additional SQL files..."
    for sqlfile in sql/*.sql; do
        filename=$(basename "$sqlfile")
        if [ "$filename" != "database.sql" ] && [ -f "$sqlfile" ]; then
            echo "Found: $filename"
            # You can add logic here to import specific files if needed
        fi
    done

    echo "Database initialization completed successfully."
    echo "Admin user created: username=admin, password=${ADMIN_PASS}"
    
    # Cleanup
    cd /
    rm -rf /tmp/openemr /tmp/import_db.sql
fi

rm -f /tmp/root.cnf
echo "Script completed successfully!"
