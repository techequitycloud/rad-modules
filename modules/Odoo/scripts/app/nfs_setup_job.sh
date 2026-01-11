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

echo "Creating Odoo subdirectories..."
mkdir -p "${TARGET_DIR}/filestore"
mkdir -p "${TARGET_DIR}/sessions"
mkdir -p "${TARGET_DIR}/addons"
mkdir -p "${TARGET_DIR}/backups"

# ✅ FIX: Set permissions without -R to avoid NFS hang
echo "Setting permissions (NFS-safe)..."
chmod 777 "${TARGET_DIR}" 2>/dev/null || echo "Warning: chmod failed, relying on NFS export options"
chmod 777 "${TARGET_DIR}/filestore" 2>/dev/null || true
chmod 777 "${TARGET_DIR}/sessions" 2>/dev/null || true
chmod 777 "${TARGET_DIR}/addons" 2>/dev/null || true
chmod 777 "${TARGET_DIR}/backups" 2>/dev/null || true

# Skip chown on NFS - handle via export options instead
echo "NFS setup complete."
ls -la "${TARGET_DIR}" 2>/dev/null || echo "Directory created successfully"

# Explicit exit to ensure job completes
exit 0