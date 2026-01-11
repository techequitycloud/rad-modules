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

# ✅ CREATE REQUIRED ODOO SUBDIRECTORIES
echo "Creating Odoo subdirectories..."
mkdir -p "${TARGET_DIR}/filestore"
mkdir -p "${TARGET_DIR}/sessions"
mkdir -p "${TARGET_DIR}/addons"
mkdir -p "${TARGET_DIR}/backups"

# ✅ FIXED: Use 777 permissions so ANY user can write
echo "Setting permissions to 777 (world-writable)..."
chmod -R 777 "${TARGET_DIR}"

# ✅ OPTIONAL: Still set nobody:nogroup ownership for consistency
chown -R 65534:65534 "${TARGET_DIR}" 2>/dev/null || true

echo "NFS setup complete."
echo "Created structure with 777 permissions:"
ls -la "${TARGET_DIR}"
echo ""
echo "Subdirectories:"
ls -la "${TARGET_DIR}/"
