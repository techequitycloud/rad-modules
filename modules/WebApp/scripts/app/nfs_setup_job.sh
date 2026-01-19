#!/bin/sh
set -e
echo "=== NFS Setup Job ==="

MOUNT_POINT="/mnt/nfs"
TARGET_DIR="${MOUNT_POINT}/${DIR_NAME}"

echo "Target Directory: ${TARGET_DIR}"

if [ ! -d "${MOUNT_POINT}" ]; then
  echo "Error: Mount point ${MOUNT_POINT} does not exist."
  exit 1
fi

if [ -d "${TARGET_DIR}" ]; then
  echo "Directory exists. Cleaning up contents..."
  find "${TARGET_DIR}" -mindepth 1 -delete
else
  echo "Creating directory..."
  mkdir -p "${TARGET_DIR}"
fi

echo "Setting permissions (NFS-safe)..."
chmod 777 "${TARGET_DIR}" 2>/dev/null || echo "Warning: chmod failed, relying on NFS export options"

echo "NFS setup complete."
ls -la "${TARGET_DIR}" 2>/dev/null || echo "Directory created successfully"

# Kill any background processes
kill $(jobs -p) 2>/dev/null || true

# Sync filesystem
sync

# Explicit exit with success
exit 0
