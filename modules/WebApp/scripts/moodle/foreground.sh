#!/bin/bash
read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
trap "kill -TERM -$pgrp; exit" EXIT TERM KILL SIGKILL SIGTERM SIGQUIT

# Clean up existing env file
rm -f /root/env.sh
touch /root/env.sh

# Dump all environment variables
printenv | sed 's/^\(.*\)$/export \1/g' > /root/env.sh

# Ensure APP_URL is correctly formatted and exported (overwrite if exists)
export APP_URL=https://$(echo "$APP_URL" | tr " " "\n"  | sed 's/^"//; s/"$//; s~^https\?://~~; s/:[0-9]\+$//')
if grep -q "^export APP_URL=" /root/env.sh >/dev/null 2>&1; then
    sed -i "s|^export APP_URL=.*|export APP_URL=$APP_URL|" /root/env.sh
else
    echo "export APP_URL=$APP_URL" >> /root/env.sh
fi

echo "Setting max_input_vars variable in /etc/php/8.3/apache2/php.ini to 5000"
sed -i "s/.*max_input_vars.*/max_input_vars = 5000/" /etc/php/8.3/apache2/php.ini

/usr/sbin/cron
source /etc/apache2/envvars
tail -F /var/log/apache2/* 2>/dev/null &
echo "Starting Apache Web Server..."
mkdir -p /var/run/apache2
chown -R www-data:www-data /var/run/apache2
exec apache2 -D FOREGROUND
