#!/bin/bash
set -e

# Inputs:
# NFS_BASE_PATH (e.g. /share/app-name-tenant-id-random-id)

echo "Starting NFS Cleanup..."
echo "NFS Path: $NFS_BASE_PATH"

if [ -z "$NFS_BASE_PATH" ] || [ "$NFS_BASE_PATH" = "/" ] || [ "$NFS_BASE_PATH" = "." ]; then
    echo "Error: Invalid or dangerous NFS_BASE_PATH: '$NFS_BASE_PATH'. Aborting cleanup."
    exit 1
fi

MOUNT_POINT="/mnt/nfs"
TARGET_DIR="${MOUNT_POINT}${NFS_BASE_PATH}"

echo "Target Directory: $TARGET_DIR"

if [ ! -d "$MOUNT_POINT" ]; then
    echo "Error: Mount point $MOUNT_POINT does not exist."
    exit 1
fi

if [ -d "$TARGET_DIR" ]; then
    # Double check to ensure we are inside mount point
    case "$TARGET_DIR" in
        "$MOUNT_POINT"/*)
            echo "Removing directory: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
            ;;
        *)
            echo "Error: Target directory is not within mount point. Aborting."
            exit 1
            ;;
    esac
else
    echo "Directory $TARGET_DIR does not exist."
fi

echo "NFS Cleanup complete."
