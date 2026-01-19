#!/bin/sh
set -e

echo "=== NFS Setup Job Started ==="
echo "Environment:"
echo "  DIR_NAME: ${DIR_NAME}"
echo "  Hostname: $(hostname)"
echo "  Date: $(date)"
echo ""

MOUNT_POINT="/mnt/nfs"
TARGET_DIR="${MOUNT_POINT}/${DIR_NAME}"

echo "Configuration:"
echo "  Mount Point: ${MOUNT_POINT}"
echo "  Target Directory: ${TARGET_DIR}"
echo ""

# Check if mount point exists
echo "Step 1: Checking mount point..."
if [ ! -d "${MOUNT_POINT}" ]; then
  echo "❌ Error: Mount point ${MOUNT_POINT} does not exist."
  echo "Available directories in /mnt:"
  ls -la /mnt/ || true
  exit 1
fi
echo "✓ Mount point exists"

# Check if we can access the NFS mount
echo ""
echo "Step 2: Checking NFS mount accessibility..."
if ! ls -la "${MOUNT_POINT}" > /dev/null 2>&1; then
  echo "❌ Error: Cannot access NFS mount at ${MOUNT_POINT}"
  echo "Mount information:"
  mount | grep nfs || echo "No NFS mounts found"
  exit 1
fi
echo "✓ NFS mount is accessible"
echo "NFS mount contents:"
ls -la "${MOUNT_POINT}" || true

# Create or clean directory
echo ""
echo "Step 3: Setting up target directory..."
if [ -d "${TARGET_DIR}" ]; then
  echo "Directory exists. Cleaning up contents..."
  ITEM_COUNT=$(find "${TARGET_DIR}" -mindepth 1 | wc -l)
  echo "Found $ITEM_COUNT items to clean"
  if [ "$ITEM_COUNT" -gt 0 ]; then
    find "${TARGET_DIR}" -mindepth 1 -delete && echo "✓ Cleanup complete"
  else
    echo "✓ Directory already empty"
  fi
else
  echo "Creating directory..."
  mkdir -p "${TARGET_DIR}" && echo "✓ Directory created"
fi

# Set permissions
echo ""
echo "Step 4: Setting permissions..."
if chmod 777 "${TARGET_DIR}" 2>/dev/null; then
  echo "✓ Permissions set successfully"
else
  echo "⚠ Warning: chmod failed, relying on NFS export options"
fi

# Verify the setup
echo ""
echo "Step 5: Verifying setup..."
if [ -d "${TARGET_DIR}" ]; then
  echo "✓ Target directory verified:"
  ls -lad "${TARGET_DIR}" || echo "Directory exists but cannot list details"
else
  echo "❌ Error: Target directory verification failed"
  exit 1
fi

# Final cleanup
echo ""
echo "Step 6: Final cleanup..."
# Kill any background processes
kill $(jobs -p) 2>/dev/null || true
# Sync filesystem
sync && echo "✓ Filesystem synced"

echo ""
echo "=== NFS Setup Job Completed Successfully ==="
echo "Summary:"
echo "  Target: ${TARGET_DIR}"
echo "  Status: Ready"
echo "  Time: $(date)"

# Explicit exit with success
exit 0
