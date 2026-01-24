#!/bin/sh
# Copyright 2024 Tech Equity Ltd
# Licensed under the Apache License, Version 2.0

set -e

echo "=========================================="
echo "Generating Odoo Configuration File"
echo "=========================================="

# Define config file path
CONFIG_FILE="/mnt/odoo.conf"

# Verify NFS mount is writable
if [ ! -d "/mnt" ]; then
    echo "ERROR: /mnt directory does not exist"
    exit 1
fi

if ! touch /mnt/.test 2>/dev/null; then
    echo "ERROR: Cannot write to /mnt"
    ls -la /mnt/
    exit 1
fi
rm -f /mnt/.test

echo "✅ NFS mount is writable"

# Validate required environment variables
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ]; then
    echo "ERROR: Missing required database environment variables"
    echo "DB_HOST: ${DB_HOST:-NOT SET}"
    echo "DB_USER: ${DB_USER:-NOT SET}"
    echo "DB_PASSWORD: ${DB_PASSWORD:+SET}"
    echo "DB_NAME: ${DB_NAME:-NOT SET}"
    exit 1
fi

echo "Environment variables validated"
echo "DB_HOST: $DB_HOST"
echo "DB_PORT: ${DB_PORT:-5432}"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"

# Generate configuration content
cat <<'EOF' > "$CONFIG_FILE"
[options]
#########################################################################
# Database Configuration
#########################################################################
db_host = ${DB_HOST}
db_port = ${DB_PORT}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
db_name = ${DB_NAME}
db_maxconn = 64
db_template = template0

#########################################################################
# Admin Password
#########################################################################
admin_passwd = ${ODOO_MASTER_PASS}

#########################################################################
# Paths
#########################################################################
data_dir = /mnt/filestore
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons

#########################################################################
# Server Configuration
#########################################################################
xmlrpc_port = 8069
longpolling_port = 8072
proxy_mode = True
logfile = /var/log/odoo/odoo.log
log_level = info
log_handler = :INFO
log_db = False

#########################################################################
# Worker Configuration
#########################################################################
workers = 4
max_cron_threads = 2

#########################################################################
# Resource Limits (in bytes)
#########################################################################
# Hard limit: 1.5GB per worker
limit_memory_hard = 1610612736

# Soft limit: 640MB per worker
limit_memory_soft = 671088640

# Request limit: 8192 requests per worker before restart
limit_request = 8192

#########################################################################
# Time Limits (in seconds)
#########################################################################
# CPU time limit: 10 minutes
limit_time_cpu = 600

# Real time limit: 20 minutes
limit_time_real = 1200

# Cron time limit: unlimited
limit_time_real_cron = -1

#########################################################################
# Security
#########################################################################
list_db = False

#########################################################################
# Performance
#########################################################################
server_wide_modules = base,web
unaccent = True
EOF

# Now substitute the environment variables
# Using a temporary file to avoid issues with heredoc
TMP_FILE=$(mktemp)
envsubst < "$CONFIG_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$CONFIG_FILE"

# Append SMTP configuration if host is set
if [ -n "$SMTP_HOST" ]; then
    echo "" >> "$CONFIG_FILE"
    echo "#########################################################################" >> "$CONFIG_FILE"
    echo "# SMTP Configuration" >> "$CONFIG_FILE"
    echo "#########################################################################" >> "$CONFIG_FILE"
    echo "smtp_server = $SMTP_HOST" >> "$CONFIG_FILE"
    echo "smtp_port = ${SMTP_PORT:-25}" >> "$CONFIG_FILE"
    
    if [ -n "$SMTP_USER" ]; then
        echo "smtp_user = $SMTP_USER" >> "$CONFIG_FILE"
    fi
    
    if [ -n "$SMTP_PASSWORD" ]; then
        echo "smtp_password = $SMTP_PASSWORD" >> "$CONFIG_FILE"
    fi
    
    if [ "$SMTP_SSL" = "true" ]; then
        echo "smtp_ssl = True" >> "$CONFIG_FILE"
    else
        echo "smtp_ssl = False" >> "$CONFIG_FILE"
    fi
    
    if [ -n "$EMAIL_FROM" ]; then
        echo "email_from = $EMAIL_FROM" >> "$CONFIG_FILE"
    fi
    
    echo "✅ SMTP configuration added"
fi

# Set proper permissions (Odoo runs as UID 101)
chown 101:101 "$CONFIG_FILE" 2>/dev/null || echo "Warning: Could not set ownership (may not have permission)"
chmod 640 "$CONFIG_FILE"

echo "✅ Configuration file created at $CONFIG_FILE"
echo ""
echo "File permissions:"
ls -la "$CONFIG_FILE"
echo ""
echo "Configuration file contents (with secrets masked):"
echo "=========================================="
# Print config but mask sensitive values
sed -e 's/\(password.*=\).*/\1 ***MASKED***/g' \
    -e 's/\(admin_passwd.*=\).*/\1 ***MASKED***/g' \
    "$CONFIG_FILE"
echo "=========================================="
echo ""
echo "✅ Odoo configuration generation complete"
