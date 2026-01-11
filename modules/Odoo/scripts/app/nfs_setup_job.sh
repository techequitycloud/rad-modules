#!/bin/sh
set -e
echo "=== NFS Setup Job ==="

# MOUNT_POINT is where we mounted the NFS share in the container (e.g., /mnt/nfs)
MOUNT_POINT="/mnt/nfs"
TARGET_DIR="${MOUNT_POINT}/${DIR_NAME}"

# Odoo user UID and GID (from the Odoo container)
ODOO_UID=103
ODOO_GID=101

echo "Target Directory: ${TARGET_DIR}"
echo "Odoo User: UID=${ODOO_UID}, GID=${ODOO_GID}"

# Ensure parent directory exists (it should if we mounted correctly)
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

# ✅ CREATE REQUIRED ODOO SUBDIRECTORIES
echo "Creating Odoo subdirectories..."
mkdir -p "${TARGET_DIR}/filestore"
mkdir -p "${TARGET_DIR}/sessions"
mkdir -p "${TARGET_DIR}/addons"
mkdir -p "${TARGET_DIR}/backups"

# ✅ Set ownership to Odoo user
echo "Setting ownership to Odoo user (${ODOO_UID}:${ODOO_GID})..."
chown -R ${ODOO_UID}:${ODOO_GID} "${TARGET_DIR}"

# ✅ Use 775 for directories (owner and group can write)
echo "Setting directory permissions to 775..."
find "${TARGET_DIR}" -type d -exec chmod 775 {} \;

# ✅ Use 664 for files (owner and group can write)
echo "Setting file permissions to 664..."
find "${TARGET_DIR}" -type f -exec chmod 664 {} \; 2>/dev/null || true

echo ""
echo "=========================================="
echo "✅ NFS setup complete!"
echo "=========================================="
echo "Created structure:"
ls -la "${TARGET_DIR}"
echo ""
echo "Subdirectories:"
ls -la "${TARGET_DIR}/" 2>/dev/null || echo "(empty)"
