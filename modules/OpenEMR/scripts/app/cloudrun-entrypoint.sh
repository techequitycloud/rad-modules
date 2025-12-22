#!/bin/sh
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

echo "=== OpenEMR Cloud Run Entrypoint ==="
echo "Starting at: $(date)"

# Wait for database to be ready
echo "Waiting for database connection..."
MAX_TRIES=30
TRIES=0

while [ $TRIES -lt $MAX_TRIES ]; do
    if mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" -e "SELECT 1" > /dev/null 2>&1; then
        echo "✓ Database connection established"
        break
    fi
    TRIES=$((TRIES + 1))
    echo "Waiting for database... ($TRIES/$MAX_TRIES)"
    sleep 2
done

if [ $TRIES -eq $MAX_TRIES ]; then
    echo "ERROR: Could not connect to database after $MAX_TRIES attempts"
    exit 1
fi

# Verify OpenEMR installation
echo "=== Verifying OpenEMR Installation ==="

# Find OpenEMR root directory
OPENEMR_ROOT="/var/www/localhost/htdocs/openemr"
if [ ! -d "$OPENEMR_ROOT" ]; then
    echo "OpenEMR not found at $OPENEMR_ROOT, searching..."
    OPENEMR_ROOT=$(find / -name "openemr" -type d 2>/dev/null | grep -v proc | head -1)
    if [ -z "$OPENEMR_ROOT" ]; then
        echo "ERROR: OpenEMR installation not found!"
        exit 1
    fi
fi

echo "✓ OpenEMR found at: $OPENEMR_ROOT"

# Check templates directory
echo "=== Checking Templates ==="
TEMPLATES_DIR="$OPENEMR_ROOT/templates"
LOGIN_DIR="$TEMPLATES_DIR/login"
LAYOUTS_DIR="$LOGIN_DIR/layouts"

if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "ERROR: Templates directory not found!"
    exit 1
fi

echo "✓ Templates directory: $TEMPLATES_DIR"

# List available login templates
echo "=== Available Login Templates ==="
if [ -d "$LAYOUTS_DIR" ]; then
    echo "Login layouts found:"
    ls -la "$LAYOUTS_DIR/"
else
    echo "WARNING: Layouts directory not found"
fi

# Determine which template to use
# Available templates in OpenEMR 7.0.3:
# - layouts/horizontal_band_left_logo
# - layouts/horizontal_band_right_logo
# - layouts/horizontal_box_left_logo
# - layouts/horizontal_box_right_logo
# - layouts/vertical_band
# - layouts/vertical_box

LOGIN_TEMPLATE=""

# Check for available templates (in order of preference)
if [ -f "$LAYOUTS_DIR/horizontal_band_left_logo.html.twig" ]; then
    LOGIN_TEMPLATE="layouts/horizontal_band_left_logo"
    echo "✓ Using: layouts/horizontal_band_left_logo"
elif [ -f "$LAYOUTS_DIR/horizontal_box_left_logo.html.twig" ]; then
    LOGIN_TEMPLATE="layouts/horizontal_box_left_logo"
    echo "✓ Using: layouts/horizontal_box_left_logo"
elif [ -f "$LAYOUTS_DIR/vertical_box.html.twig" ]; then
    LOGIN_TEMPLATE="layouts/vertical_box"
    echo "✓ Using: layouts/vertical_box"
elif [ -f "$LOGIN_DIR/horizontal_band.html.twig" ]; then
    LOGIN_TEMPLATE="horizontal_band"
    echo "✓ Using: horizontal_band"
elif [ -f "$LOGIN_DIR/horizontal_box.html.twig" ]; then
    LOGIN_TEMPLATE="horizontal_box"
    echo "✓ Using: horizontal_box"
else
    echo "ERROR: No suitable login template found!"
    echo "Available files in login directory:"
    find "$LOGIN_DIR" -name "*.twig" -type f
    exit 1
fi

echo "Selected login template: ${LOGIN_TEMPLATE}"

# Verify the template file exists
TEMPLATE_PATH="$LOGIN_DIR/${LOGIN_TEMPLATE}.html.twig"
if [ -f "$TEMPLATE_PATH" ]; then
    echo "✓ Template file verified: $TEMPLATE_PATH"
else
    echo "ERROR: Template file not found: $TEMPLATE_PATH"
    exit 1
fi

# Check database status
echo "=== Checking Database ==="
TABLE_COUNT=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME}';" 2>/dev/null || echo "0")
echo "Database '${DB_NAME}' has ${TABLE_COUNT} tables"

if [ "$TABLE_COUNT" -eq "0" ]; then
    echo "ERROR: Database is empty! Please run the import-db job first."
    exit 1
fi

# Check globals table
echo "=== Checking Globals Configuration ==="
GLOBALS_COUNT=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -sN -e "SELECT COUNT(*) FROM globals;" 2>/dev/null || echo "0")
echo "Globals table has ${GLOBALS_COUNT} entries"

# Set or update login_page_layout
echo "=== Setting Login Page Layout ==="
mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" <<EOFGLOBALS
INSERT INTO globals (gl_name, gl_value) VALUES ('login_page_layout', '${LOGIN_TEMPLATE}')
ON DUPLICATE KEY UPDATE gl_value='${LOGIN_TEMPLATE}';
EOFGLOBALS

echo "✓ login_page_layout set to: ${LOGIN_TEMPLATE}"

# Verify the setting
CURRENT_LAYOUT=$(mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" -sN -e "SELECT gl_value FROM globals WHERE gl_name='login_page_layout';" 2>/dev/null || echo "")
echo "✓ Verified login_page_layout = ${CURRENT_LAYOUT}"

# Ensure other required globals exist
echo "=== Ensuring Required Globals ==="
mysql -h"${DB_HOST}" -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" <<'EOFGLOBALS2'
INSERT INTO globals (gl_name, gl_value) VALUES
    ('language_default', 'English (Standard)'),
    ('show_label_login', '0'),
    ('show_tagline_on_login', '0'),
    ('display_acknowledgements_on_login', '0'),
    ('show_labels_on_login_form', '0'),
    ('show_primary_logo', '1'),
    ('logo_position', 'left'),
    ('openemr_name', 'OpenEMR')
ON DUPLICATE KEY UPDATE gl_name=gl_name;
EOFGLOBALS2

echo "✓ Required globals ensured"

# Check OpenEMR configuration files
echo "=== Checking OpenEMR Configuration ==="
SITES_DIR="$OPENEMR_ROOT/sites/default"

if [ -d "$SITES_DIR" ]; then
    echo "✓ Sites directory exists: $SITES_DIR"
    
    # Check sqlconf.php
    if [ -f "$SITES_DIR/sqlconf.php" ]; then
        echo "✓ sqlconf.php exists"
    else
        echo "⚠ sqlconf.php not found, creating..."
        cat > "$SITES_DIR/sqlconf.php" <<EOFSQL
<?php
\$host = '${DB_HOST}';
\$port = '3306';
\$login = '${DB_USER}';
\$pass = '${DB_PASS}';
\$dbase = '${DB_NAME}';

\$sqlconf = array();
global \$sqlconf;
\$sqlconf["host"] = \$host;
\$sqlconf["port"] = \$port;
\$sqlconf["login"] = \$login;
\$sqlconf["pass"] = \$pass;
\$sqlconf["dbase"] = \$dbase;

\$disable_utf8_flag = false;
?>
EOFSQL
        chmod 644 "$SITES_DIR/sqlconf.php"
        echo "✓ sqlconf.php created"
    fi
    
    # Check config.php
    if [ ! -f "$SITES_DIR/config.php" ]; then
        echo "⚠ config.php not found, creating..."
        cat > "$SITES_DIR/config.php" <<'EOFCONFIG'
<?php
$config = 1;
?>
EOFCONFIG
        chmod 644 "$SITES_DIR/config.php"
        echo "✓ config.php created"
    else
        echo "✓ config.php exists"
    fi
else
    echo "WARNING: Sites directory not found at $SITES_DIR"
fi

# Display environment info
echo "=== Environment Information ==="
echo "PHP Version: $(php -v | head -1)"
echo "PHP Memory Limit: $(php -r 'echo ini_get("memory_limit");')"
echo "DB Host: ${DB_HOST}"
echo "DB Name: ${DB_NAME}"
echo "DB User: ${DB_USER}"
echo "Login Template: ${LOGIN_TEMPLATE}"

echo "=== Initialization Complete ==="
echo "Starting OpenEMR application..."

# Verify the command to execute
if [ $# -eq 0 ]; then
    echo "No command provided, looking for default OpenEMR entrypoint..."
    if [ -f "/usr/local/bin/docker-entrypoint.sh" ]; then
        echo "Executing: /usr/local/bin/docker-entrypoint.sh"
        exec /usr/local/bin/docker-entrypoint.sh
    else
        echo "ERROR: No entrypoint found!"
        exit 1
    fi
else
    echo "Executing: $@"
    exec "$@"
fi