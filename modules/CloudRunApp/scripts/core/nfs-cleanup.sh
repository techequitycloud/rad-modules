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
            # Use timeout to prevent indefinite hanging (Cloud Run job timeout is 900s)
            # Set internal timeout slightly lower to allow for graceful exit logging
            # Use SIGKILL (-9) to force termination if hung
            if timeout -s 9 850 rm -rf "$TARGET_DIR"; then
                echo "Directory removed successfully."
            else
                EXIT_CODE=$?
                echo "Error: Failed to remove directory (Exit Code: $EXIT_CODE). Operation might have timed out."
                # Don't fail the job if cleanup times out, just warn.
                # This prevents Terraform destroy from hanging indefinitely or failing.
                echo "Warning: Cleanup timed out or failed. Proceeding to exit to avoid blocking destruction."
            fi
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
# Ensure buffers are flushed and exit explicitly
sync
echo "Exiting with success status"
exit 0
