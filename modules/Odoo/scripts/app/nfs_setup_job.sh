#!/bin/sh
set -e
echo "=== NFS Setup Job ==="

# MOUNT_POINT is where we mounted the NFS share in the container (e.g., /mnt/nfs)
MOUNT_POINT="/mnt/nfs"
TARGET_DIR="${MOUNT_POINT}/${DIR_NAME}"

echo "Target Directory: ${TARGET_DIR}"

# Ensure parent directory exists (it should if we mounted correctly)
if [ ! -d "${MOUNT_POINT}" ]; then
  echo "Error: Mount point ${MOUNT_POINT} does not exist."
  exit 1
fi

if [ -d "${TARGET_DIR}" ]; then
  echo "Directory exists. Cleaning up contents..."
  # Use find to delete to avoid argument list too long if many files
  find "${TARGET_DIR}" -mindepth 1 -delete
else
  echo "Creating directory..."
  mkdir -p "${TARGET_DIR}"
fi

# Permissions
# We want nobody:nogroup (65534:65534) which is standard for NFS anonymous access
echo "Setting permissions..."
chown -R 65534:65534 "${TARGET_DIR}"
chmod 775 "${TARGET_DIR}"

echo "NFS setup complete."
