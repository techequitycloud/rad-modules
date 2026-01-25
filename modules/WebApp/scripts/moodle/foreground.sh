#!/bin/bash
read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
trap "kill -TERM -$pgrp; exit" EXIT TERM KILL SIGKILL SIGTERM SIGQUIT

source /etc/apache2/envvars
# Create log files if they don't exist so tail doesn't complain
touch /var/log/apache2/access.log /var/log/apache2/error.log
tail -F /var/log/apache2/* 2>/dev/null &

echo "Starting Apache Web Server..."
exec apache2 -D FOREGROUND
