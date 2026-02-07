set -e
echo "Creating Moodle data directories..."
mkdir -p /mnt/filedir /mnt/temp /mnt/cache /mnt/localcache

echo "Setting permissions..."
chown -R 33:33 /mnt
chmod -R 2770 /mnt

echo "NFS permissions initialized successfully"
ls -la /mnt