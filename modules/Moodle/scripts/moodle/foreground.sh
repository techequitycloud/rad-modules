#!/bin/bash
set -e

# Get process group for proper signal handling
read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
trap "echo 'Shutting down Apache...'; kill -TERM -$pgrp; wait; exit" EXIT TERM INT SIGTERM SIGINT

# Source Apache environment
source /etc/apache2/envvars

# Create log files if they don't exist
touch /var/log/apache2/access.log /var/log/apache2/error.log 2>/dev/null || true

# Tail logs in background
tail -F /var/log/apache2/*.log 2>/dev/null &

echo "Starting Apache Web Server on port 8080..."

# Start Apache in foreground
exec apache2 -D FOREGROUND
