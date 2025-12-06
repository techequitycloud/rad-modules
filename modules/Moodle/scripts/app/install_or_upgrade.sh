#!/bin/bash
set -e

# Checks if Moodle is installed and either installs or upgrades it.

# Environment variables expected:
# DB_HOST, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT
# APP_URL
# MOODLE_ADMIN_USER, MOODLE_ADMIN_PASSWORD, MOODLE_ADMIN_EMAIL
# MOODLE_FULLNAME, MOODLE_SHORTNAME

# Check if database connection works and if the config table exists
echo "Checking Moodle installation status..."

# Create a temporary config file for check if needed, or use existing logic
# Moodle CLI scripts rely on config.php. The container should have one.

# We assume config.php is already in place and using env vars.

# Check if tables exist.
# A simple way is to check if we can run the upgrade script with --test option (if supported) or check for a specific table.
# Moodle install_database.php fails if tables exist.
# Moodle upgrade.php fails if tables do not exist.

# We can try upgrade.php first. If it fails due to "not installed", we run install.

# But upgrade.php might fail for other reasons.
# A better check is to use PHP to check the DB.

php -r "
require_once('/var/www/html/config.php');
try {
    \$db = \$DB->get_record('config', array('name'=>'release'));
    if (\$db) {
        exit(0); // Installed
    } else {
        exit(1); // Not installed (or config table missing/empty)
    }
} catch (Exception \$e) {
    exit(1); // Not installed (DB connection might be fine but tables missing)
}
"

STATUS=$?

if [ $STATUS -eq 0 ]; then
    echo "Moodle seems to be installed. Running upgrade..."
    php /var/www/html/admin/cli/upgrade.php --non-interactive --allow-unstable
else
    echo "Moodle does not seem to be installed. Running install..."
    # Ensure all required vars are present
    if [ -z "$MOODLE_ADMIN_PASSWORD" ]; then
        echo "Error: MOODLE_ADMIN_PASSWORD is not set."
        exit 1
    fi

    php /var/www/html/admin/cli/install_database.php \
        --lang=en \
        --adminuser="$MOODLE_ADMIN_USER" \
        --adminpass="$MOODLE_ADMIN_PASSWORD" \
        --adminemail="$MOODLE_ADMIN_EMAIL" \
        --fullname="$MOODLE_FULLNAME" \
        --shortname="$MOODLE_SHORTNAME" \
        --agree-license
fi

# Clear caches after operation
php /var/www/html/admin/cli/purge_caches.php
