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
  echo "Directory exists."
else
  echo "Creating directory..."
  mkdir -p "${TARGET_DIR}"
fi

echo "Setting permissions..."
chmod 777 "${TARGET_DIR}" || echo "Warning: chmod failed"

ls -la "${TARGET_DIR}"
exit 0
