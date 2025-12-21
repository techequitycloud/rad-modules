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
apk add --no-cache mariadb-client python3 py3-pip unzip curl

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
    echo "No backup file provided. Populating with initial database schema..."

    # Format version string (e.g. 7.0.3 -> v7_0_3)
    # Strip leading 'v' if present to avoid v7.0.3 -> vv7_0_3
    CLEAN_VERSION="${APP_VERSION#v}"
    VERSION_UNDERSCORE="v$(echo ${CLEAN_VERSION} | tr '.' '_')"
    SQL_URL="https://raw.githubusercontent.com/openemr/openemr/${VERSION_UNDERSCORE}/sql/database.sql"

    echo "DEBUG: APP_VERSION=${APP_VERSION}"
    echo "DEBUG: CLEAN_VERSION=${CLEAN_VERSION}"
    echo "DEBUG: VERSION_UNDERSCORE=${VERSION_UNDERSCORE}"
    echo "Downloading database.sql from ${SQL_URL}..."

    if curl -f -L -o database.sql "${SQL_URL}"; then
        echo "Download successful."

        echo "Importing database.sql..."
        # Disable strict mode to allow 0000-00-00 dates present in OpenEMR schema
        if (echo "SET @@SESSION.sql_mode = '';"; cat database.sql) | mysql --defaults-file=/tmp/root.cnf "${DB_NAME}"; then
            echo "Database population complete."
            rm -f database.sql
        else
            echo "ERROR: Failed to import database.sql into ${DB_NAME}"
            exit 1
        fi
    else
        echo "ERROR: Failed to download database.sql from ${SQL_URL}. Check if version tag exists."
        exit 1
    fi
fi

rm -f /tmp/root.cnf
echo "Script completed successfully!"
