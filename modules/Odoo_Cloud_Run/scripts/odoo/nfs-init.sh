set -e
echo "=========================================="
echo "NFS Initialization"
echo "=========================================="

echo "Current /mnt contents:"
ls -la /mnt/ 2>/dev/null || echo "Empty or not accessible"

echo "Creating directories..."
mkdir -p /mnt/filestore /mnt/sessions /mnt/backups

echo "Setting ownership and permissions..."
timeout 30 chown 101:101 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null || echo "Warning: chown failed or timed out"
timeout 30 chmod 777 /mnt/filestore /mnt/sessions /mnt/backups 2>/dev/null || echo "Warning: chmod failed or timed out"
echo "Permissions set"

echo ""
echo "Final directory listing:"
ls -la /mnt/
echo ""
echo "Filestore permissions:"
ls -la /mnt/filestore/
echo ""

if touch /mnt/filestore/.test 2>/dev/null; then
  echo "Write test successful"
  rm -f /mnt/filestore/.test
else
  echo "Write test failed"
  echo "Current user: $(id)"
fi

echo "NFS initialization complete"