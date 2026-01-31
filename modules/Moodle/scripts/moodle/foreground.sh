#!/bin/bash
set -e
read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
trap "kill -TERM -$pgrp; exit" EXIT TERM KILL SIGKILL SIGTERM SIGQUIT
export APP_URL=https://$(echo "$APP_URL" | tr " " "\n"  | sed 's/^"//; s/"$//; s~^https\?://~~; s/:[0-9]\+$//')
if grep -q "^export APP_URL=" /root/env.sh >/dev/null 2>&1; then
    echo "Updating APP_URL variable in /root/env.sh to $APP_URL"
    sed -i "s/^export APP_URL=.*/export APP_URL=$APP_URL/" /root/env.sh
else
    echo "Adding APP_URL variable $APP_URL in /root/env.sh"
    echo "export APP_URL=$APP_URL" >> /root/env.sh
fi
echo "Setting max_input_vars variable in /etc/php/8.3/apache2/php.ini to 5000"
sed -i "s/.*max_input_vars.*/max_input_vars = 5000/" /etc/php/8.3/apache2/php.ini
echo | cat /root/env.sh
/usr/sbin/cron
source /etc/apache2/envvars

# Set default values if environment variables are missing
: "${APACHE_RUN_DIR:=/var/run/apache2}"
: "${APACHE_LOCK_DIR:=/var/lock/apache2}"
: "${APACHE_LOG_DIR:=/var/log/apache2}"
: "${APACHE_PID_FILE:=/var/run/apache2/apache2.pid}"
: "${APACHE_RUN_USER:=www-data}"
: "${APACHE_RUN_GROUP:=www-data}"

export APACHE_RUN_DIR APACHE_LOCK_DIR APACHE_LOG_DIR APACHE_PID_FILE APACHE_RUN_USER APACHE_RUN_GROUP

mkdir -p "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR" "$APACHE_LOG_DIR"
chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$APACHE_RUN_DIR" "$APACHE_LOCK_DIR" "$APACHE_LOG_DIR"
tail -F /var/log/apache2/* 2>/dev/null &

# Configure Apache to listen on Cloud Run PORT
echo "Configuring Apache to listen on port ${PORT:-8080}..."
sed -i "s/80/${PORT:-8080}/g" /etc/apache2/ports.conf /etc/apache2/sites-enabled/*.conf

exec apache2 -D FOREGROUND
