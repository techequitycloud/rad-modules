#!/bin/bash
set -e

# Directory where Cloud SQL sockets are mounted (read-only likely)
SEARCH_DIR="/var/run/mysqld"

# Directory where we will create the symlink (writable)
TARGET_DIR="/tmp"
SOCKET_LINK="$TARGET_DIR/mysqld.sock"

echo "Checking for Cloud SQL socket in $SEARCH_DIR..."

# Check if the search directory exists
if [ -d "$SEARCH_DIR" ]; then
    # Find the first socket file in the directory
    FOUND_SOCKET=$(find "$SEARCH_DIR" -maxdepth 1 -type s | head -n 1)

    if [ -n "$FOUND_SOCKET" ]; then
        echo "Found socket: $FOUND_SOCKET"

        # Create symlink in writable location
        echo "Creating symlink from $FOUND_SOCKET to $SOCKET_LINK"
        ln -sf "$FOUND_SOCKET" "$SOCKET_LINK"

        # Override WORDPRESS_DB_HOST to point to the symlink
        export WORDPRESS_DB_HOST="localhost:$SOCKET_LINK"
        echo "Set WORDPRESS_DB_HOST to $WORDPRESS_DB_HOST"
    else
        echo "No socket file found in $SEARCH_DIR."
    fi
else
    echo "Directory $SEARCH_DIR does not exist."
fi

echo "Starting WordPress..."
exec docker-entrypoint.sh "$@"
