#!/bin/bash
set -e

echo "================================================"
echo "Starting OpenEMR NFS Setup Job"
echo "================================================"

# Expected Env Vars:
# NFS_MOUNT_PATH
# DB_HOST, DB_NAME, DB_USER, DB_PASS, ROOT_PASS
# BACKUP_FILEID

# Env Var Fallbacks
DB_HOST="${DB_HOST:-$MYSQL_HOST}"
DB_PASS="${DB_PASS:-$DB_PASSWORD}"
ROOT_PASS="${ROOT_PASS:-$ROOT_PASSWORD}"
DB_USER="${DB_USER:-$MYSQL_USER}"
DB_NAME="${DB_NAME:-$MYSQL_DATABASE}"

if [ -z "$NFS_MOUNT_PATH" ]; then
  echo "Error: NFS_MOUNT_PATH is not set."
  exit 1
fi

APP_DIR="$NFS_MOUNT_PATH"

# Install packages
echo "Installing packages..."
apk add --no-cache bash python3 py3-pip unzip curl sed

# Install gdown
echo "Installing gdown..."
pip3 install gdown --break-system-packages

echo "Working Directory: $APP_DIR"

# Set ownership (OpenEMR runs as 1000)
echo "Setting ownership..."
chown 1000:1000 "$APP_DIR"
chmod 775 "$APP_DIR"

# Download and Restore Backup if provided
if [ -n "$BACKUP_FILEID" ]; then
  echo "Downloading backup..."
  # Use a temp file
  BACKUP_FILE="/tmp/backup.zip"

  if gdown $BACKUP_FILEID -O "$BACKUP_FILE"; then
    echo "✓ Backup downloaded"

    if [ -f "$BACKUP_FILE" ]; then
      echo "Extracting backup to $APP_DIR..."
      # Clean target dir
      rm -rf "$APP_DIR"/*

      # Unzip to temp
      mkdir -p /tmp/restore
      unzip -q "$BACKUP_FILE" -d /tmp/restore

      # Move contents
      if [ -d "/tmp/restore/$DB_NAME" ]; then
         mv /tmp/restore/$DB_NAME/* "$APP_DIR"/
      else
         mv /tmp/restore/* "$APP_DIR"/
      fi

      echo "✓ Files restored"

      # Update sqlconf.php
      SQLCONF_FILE="$APP_DIR/default/sqlconf.php"
      if [ -f "$SQLCONF_FILE" ]; then
        echo "Updating $SQLCONF_FILE..."
        sed -i "s/\$host\s*=\s*'[^']*'/\$host = '$DB_HOST'/" "$SQLCONF_FILE"
        sed -i "s/\$port\s*=\s*'[^']*'/\$port = '3306'/" "$SQLCONF_FILE"
        sed -i "s/\$login\s*=\s*'[^']*'/\$login = '$DB_USER'/" "$SQLCONF_FILE"
        sed -i "s/\$pass\s*=\s*'[^']*'/\$pass = '$DB_PASS'/" "$SQLCONF_FILE"
        sed -i "s/\$dbase\s*=\s*'[^']*'/\$dbase = '$DB_NAME'/" "$SQLCONF_FILE"

        if ! grep -q "\$rootpass" "$SQLCONF_FILE"; then
           sed -i "/\$pass\s*=\s*'[^']*'/a \$rootpass = '$ROOT_PASS';" "$SQLCONF_FILE"
        else
           sed -i "s/\$rootpass\s*=\s*'[^']*'/\$rootpass = '$ROOT_PASS'/" "$SQLCONF_FILE"
        fi

        echo "✓ Config updated"
      else
        echo "⚠ sqlconf.php not found at $SQLCONF_FILE"
      fi

      # Permissions update
      echo "Updating permissions..."
      chown -R 1000:1000 "$APP_DIR"
      find "$APP_DIR" -type d -exec chmod 755 {} \;
      find "$APP_DIR" -type f -exec chmod 644 {} \;
      if [ -d "$APP_DIR/default/documents" ]; then
        chmod -R 755 "$APP_DIR/default/documents"
      fi
      if [ -f "$SQLCONF_FILE" ]; then
        chmod 600 "$SQLCONF_FILE"
      fi

    else
       echo "✗ Zip file not found"
       exit 1
    fi
  else
     echo "✗ Download failed"
     exit 1
  fi
else
   echo "ℹ No backup specified"
fi

echo "================================================"
echo "✓ OpenEMR NFS Setup Completed"
echo "================================================"
