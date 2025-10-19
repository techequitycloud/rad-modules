#!/bin/sh
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

# Set permissions for directories
chown -R 1000:1000 /var/www/localhost/htdocs/openemr

# Other startup commands
exec "$@"
