#!/bin/bash
set -e

# Dynamically find the Cloud SQL socket
# Cloud Run mounts the socket directory at /var/run/mysqld
# The file name is <project>:<region>:<instance>
# We need to symlink it to /tmp/mysqld.sock because WordPress expects a fixed path
# or we would need to know the instance name to set WORDPRESS_DB_HOST correctly.

SOCKET_DIR="/var/run/mysqld"
TARGET_SOCKET="/tmp/mysqld.sock"

if [ -d "$SOCKET_DIR" ]; then
    # Find the socket file. It's usually the only file there.
    SOCKET_FILE=$(find "$SOCKET_DIR" -maxdepth 1 -mindepth 1 -print -quit)

    if [ -n "$SOCKET_FILE" ]; then
        echo "Found Cloud SQL socket: $SOCKET_FILE"
        echo "Symlinking to $TARGET_SOCKET"
        ln -sf "$SOCKET_FILE" "$TARGET_SOCKET"
    else
        echo "Warning: No socket file found in $SOCKET_DIR"
    fi
else
    echo "Warning: $SOCKET_DIR does not exist"
fi

# Pass execution to the original entrypoint
exec docker-entrypoint.sh "$@"
