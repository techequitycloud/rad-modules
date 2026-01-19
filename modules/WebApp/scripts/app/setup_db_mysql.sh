#!/bin/sh
set -e
echo "=== MySQL DB Setup ==="
apk add --no-cache mariadb-client netcat-openbsd

echo "Checking connectivity..."
if ! nc -zv $DB_HOST 3306; then
  echo "Cannot reach $DB_HOST:3306"
  exit 1
fi

echo "Configuring root credentials..."
cat > /root/.my.cnf <<EOF
[client]
user=root
password=$ROOT_PASS
host=$DB_HOST
EOF
chmod 600 /root/.my.cnf

echo "Creating user..."
mysql <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
FLUSH PRIVILEGES;
EOF

echo "Creating database..."
if ! mysql -e "SHOW DATABASES LIKE '$DB_NAME'" | grep "$DB_NAME"; then
  mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  echo "Database created."
else
  echo "Database already exists."
fi

echo "Granting privileges..."
mysql <<EOF
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
GRANT GRANT OPTION ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

rm -f /root/.my.cnf
echo "Done."
