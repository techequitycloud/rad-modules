#!/usr/bin/env bash
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

# Check if we have write permission to the config file
if [ -w /etc/odoo/odoo.conf ]; then
    echo "✓ Config file is writable, updating in place..."
    sed -i "s|DB_NAME|${DB_NAME}|g" /etc/odoo/odoo.conf
else
    echo "⚠ Config file not writable, copying to /tmp..."
    cp /etc/odoo/odoo.conf /tmp/odoo.conf
    sed -i "s|DB_NAME|${DB_NAME}|g" /tmp/odoo.conf
    export ODOO_RC=/tmp/odoo.conf
fi

echo "✓ Configuration updated successfully"
echo "  DB_NAME: ${DB_NAME}"
echo "  ODOO_RC: ${ODOO_RC}"

# Other startup commands
exec "$@"
