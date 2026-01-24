#!/bin/sh
set -e

echo "Generating Odoo configuration file..."

# Define config file path
CONFIG_FILE="/mnt/odoo.conf"

# Generate configuration content
cat <<EOF > "$CONFIG_FILE"
[options]
; Database Configuration
db_host = ${DB_HOST}
db_port = ${DB_PORT:-5432}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
db_name = ${DB_NAME}
db_maxconn = 32

; Admin Password
admin_passwd = ${ODOO_MASTER_PASS}

; Paths
data_dir = /mnt/filestore
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons

; Server Configuration
xmlrpc_port = 8069
proxy_mode = True
logfile = False
log_level = info
workers = 2

; Resource Limits
limit_memory_hard = 1610612736 ; 1.5GB
limit_memory_soft = 671088640  ; 640MB
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

; SMTP Configuration
EOF

# Append SMTP configuration if host is set
if [ -n "$SMTP_HOST" ]; then
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
fi

# Set permissions
chmod 644 "$CONFIG_FILE"

echo "Odoo configuration generated at $CONFIG_FILE"
# NOTE: Not printing config file content to logs to avoid leaking secrets
