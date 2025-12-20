#!/usr/bin/env bash
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

# Set permissions for directories
# chown -R odoo:odoo /mnt /extra-addons

sed -i "s|DB_NAME|${DB_NAME}|g" /etc/odoo/odoo.conf

# Other startup commands
exec "$@"
