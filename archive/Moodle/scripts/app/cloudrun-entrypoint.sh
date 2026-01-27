#!/usr/bin/env bash
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

# Set permissions for directories
chown -R www-data:www-data /mnt

# Other startup commands
exec "$@"
