#!/usr/bin/env bash
#
# Copyright 2024 Tech Equity Ltd
#

set -eo pipefail

# Set permissions for directories
chown -R www-data:www-data /gcs/moodle-data 2>/dev/null || true

# Execute the command passed to the container
exec "$@"
