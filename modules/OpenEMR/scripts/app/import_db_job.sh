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
apk add --no-cache mariadb-client python3 py3-pip unzip curl git php83 php83-mysqli php83-pdo_mysql php83-json php83-openssl php83-curl php83-zip

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
cat > /tmp/root.cnf << EOF
[client]
user=root
password=${ROOT_PASS}
host=${DB_HOST}
EOF
chmod 600 /tmp/root.cnf

echo "Checking DB connection..."
mysql --defaults-file=/tmp/root.cnf -e 'STATUS;' || { echo "DB Connection Failed"; exit 1; }

echo "Displaying databases..."
mysql --defaults-file=/tmp/root.cnf -e 'SHOW DATABASES;'

# Create/Update User
echo "Creating/updating user ${DB_USER}..."
mysql --defaults-file=/tmp/root.cnf <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
EOF

# Create DB
echo "Creating database ${DB_NAME}..."
mysql --defaults-file=/tmp/root.cnf -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Grant Privileges
echo "Granting privileges..."
mysql --defaults-file=/tmp/root.cnf <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT GRANT OPTION ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "Privileges granted."

# Backup Restore
if [ -n "${BACKUP_FILEID}" ]; then
    echo "Attempting to download backup..."

    # gdown is in /venv/bin/gdown (already in path via activate)
    # But just in case
    if gdown "${BACKUP_FILEID}" -O "${DB_NAME}.zip"; then
        echo "Backup file downloaded successfully"

        # Drop DB before restore (to be clean)
        echo "Dropping database for restore..."
        mysql --defaults-file=/tmp/root.cnf -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
        mysql --defaults-file=/tmp/root.cnf -e "CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

        # Grant again
        mysql --defaults-file=/tmp/root.cnf <<EOF
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT GRANT OPTION ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

        echo "Unzipping..."
        mkdir -p "${DB_NAME}"
        unzip -o "${DB_NAME}.zip" -d "${DB_NAME}"

        echo "Restoring..."
        # Use DB User to restore to test permissions (or root if needed, but script used user)
        # We can use root for reliability
        mysql --defaults-file=/tmp/root.cnf "${DB_NAME}" < "${DB_NAME}/dump.sql"

        echo "Database restored successfully."

        # Cleanup
        rm -rf "${DB_NAME}" "${DB_NAME}.zip"
    else
        echo "Failed to download backup."
        exit 1
    fi
else
    echo "No backup file provided. Using OpenEMR installer for proper initialization..."

    # Clone minimal OpenEMR files needed for installation
    echo "Downloading OpenEMR installer files..."
    VERSION_TAG="v$(echo ${APP_VERSION} | tr '.' '_')"

    mkdir -p /tmp/openemr-install
    cd /tmp/openemr-install

    # Download necessary files for installation
    curl -L -o auto_configure.php "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/auto_configure.php"

    # Download library files
    mkdir -p library/classes
    curl -L -o library/classes/Installer.class.php "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/library/classes/Installer.class.php"
    curl -L -o library/globals.inc.php "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/library/globals.inc.php"
    curl -L -o library/sql_upgrade_fx.php "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/library/sql_upgrade_fx.php"

    # Download SQL files
    mkdir -p sql
    curl -L -o sql/database.sql "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/sql/database.sql"
    curl -L -o sql/official_additional_users.sql "https://raw.githubusercontent.com/openemr/openemr/${VERSION_TAG}/sql/official_additional_users.sql"

    # Download composer autoload (create minimal stub)
    mkdir -p vendor
    cat > vendor/autoload.php << 'AUTOLOADEOF'
<?php
// Minimal autoloader stub
spl_autoload_register(function ($class) {
    $file = str_replace('\\', '/', $class) . '.php';
    if (file_exists(__DIR__ . '/../library/classes/' . basename($file))) {
        require_once __DIR__ . '/../library/classes/' . basename($file);
    }
});
AUTOLOADEOF

    # Set SQL mode to allow invalid dates
    echo "Setting SQL mode..."
    mysql --defaults-file=/tmp/root.cnf <<'SQLMODEEOF'
SET GLOBAL sql_mode = 'ALLOW_INVALID_DATES,NO_ENGINE_SUBSTITUTION';
SQLMODEEOF

    # Run the OpenEMR installer
    echo "Running OpenEMR installer..."
    php83 auto_configure.php \
        server="${DB_HOST}" \
        port=3306 \
        login="${DB_USER}" \
        pass="${DB_PASS}" \
        loginhost="%" \
        root="root" \
        rootpass="${ROOT_PASS}" \
        dbname="${DB_NAME}" \
        collate="utf8mb4_general_ci"

    if [ $? -eq 0 ]; then
        echo "OpenEMR installation completed successfully."
        # Clean up
        cd /
        rm -rf /tmp/openemr-install
    else
        echo "OpenEMR installation failed."
        exit 1
    fi
fi

rm -f /tmp/root.cnf
echo "Script completed successfully!"
