#!/usr/bin/env bash
# Copyright 2024 Tech Equity Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#########################################################################
# Install Required Packages
#########################################################################

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo apt-get update >/dev/null && sudo apt install -y -q nfs-kernel-server python3 python3-pip unzip wget curl postgresql-client-16 mysql-client zip redis-server >/dev/null

# Install gdown with proper error checking
echo "Installing gdown..."
pip3 install --upgrade gdown --user >/dev/null

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo "gdown installed successfully"
else
    echo "Failed to install gdown with pip3, trying pip..."
    pip install --upgrade gdown --user >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install gdown with both pip3 and pip"
    fi
fi

echo "Installation complete! gdown is ready to use."

#########################################################################
# Setup Local Disk for NFS Share
#########################################################################

DISK_ID=/dev/sdb
MNT_DIR=/share

sudo mkdir -p $MNT_DIR

# Format disk if not already formatted
if [[ $(lsblk $DISK_ID -no fstype) != 'ext4' ]]; then
    echo "Formatting disk $DISK_ID as ext4..."
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard $DISK_ID
else
    echo "Disk $DISK_ID already formatted, checking filesystem..."
    sudo e2fsck -fp $DISK_ID
    sudo resize2fs $DISK_ID
fi

# Mount disk if not already mounted
if ! grep -qs "$MNT_DIR " /proc/mounts; then
    echo "Mounting disk to $MNT_DIR..."
    if ! grep -qs "$MNT_DIR " /etc/fstab; then
        UUID=$(blkid -s UUID -o value $DISK_ID)
        echo "UUID=$UUID $MNT_DIR ext4 rw,discard,defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo systemctl daemon-reload
    sudo mount $MNT_DIR
fi

# Ensure filesystem is mounted read-write
sudo mount -o remount,rw $MNT_DIR

# Verify mount is successful and writable
if ! mountpoint -q "$MNT_DIR"; then
    echo "ERROR: Failed to mount $MNT_DIR"
    exit 1
fi

# Test write permissions
if ! sudo touch "$MNT_DIR/.write_test" 2>/dev/null; then
    echo "ERROR: $MNT_DIR is not writable"
    mount | grep $MNT_DIR
    exit 1
fi
sudo rm -f "$MNT_DIR/.write_test"

echo "✅ Disk mounted successfully at $MNT_DIR (read-write mode)"

#########################################################################
# NFS Configuration (for shared storage)
#########################################################################

echo "Configuring NFS server..."

sudo sed -i 's/^STATDOPTS=.*/STATDOPTS="-p 2046"/' /etc/default/nfs-common
sudo touch /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_tcpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_tcpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_udpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_udpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf

# Set permissions for NFS share, excluding 'redis' directory if it exists
sudo chown nobody:nogroup "$MNT_DIR"
sudo chmod 775 "$MNT_DIR"

# Apply recursively only to files/dirs that are NOT 'redis'
sudo find "$MNT_DIR" -mindepth 1 -maxdepth 1 -not -name 'redis' -exec chown -R nobody:nogroup {} + 2>/dev/null || true
sudo find "$MNT_DIR" -mindepth 1 -maxdepth 1 -not -name 'redis' -exec chmod -R 775 {} + 2>/dev/null || true

# Configure NFS exports
sudo chmod 777 /etc/exports
sudo grep -qxF '/share *(rw,sync,no_root_squash,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_root_squash,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null

# Restart NFS server
sudo systemctl restart nfs-kernel-server

# Verify NFS exports
sudo exportfs

echo "✅ NFS server configured successfully"

#########################################################################
# Configure Redis to use STATEFUL STORAGE
#########################################################################

echo "Configuring Redis for optimal performance on stateful storage..."

# Create Redis data directory with correct permissions
REDIS_DATA_DIR="$MNT_DIR/redis"
sudo mkdir -p "$REDIS_DATA_DIR"
sudo chown -R redis:redis "$REDIS_DATA_DIR"
sudo chmod 770 "$REDIS_DATA_DIR"

# Clean up any old test files
sudo rm -f "$REDIS_DATA_DIR"/.test* 2>/dev/null || true

# Verify Redis can write to the directory
if ! sudo -u redis touch "$REDIS_DATA_DIR/.write_test" 2>/dev/null; then
    echo "ERROR: Redis user cannot write to $REDIS_DATA_DIR"
    ls -la "$REDIS_DATA_DIR"
    exit 1
fi
sudo rm -f "$REDIS_DATA_DIR/.write_test"

echo "✅ Redis data directory created: $REDIS_DATA_DIR (verified writable)"

# Create log directory
sudo mkdir -p /var/log/redis
sudo chown -R redis:redis /var/log/redis
sudo chmod 755 /var/log/redis

# Stop Redis and clean up any existing processes
sudo systemctl stop redis-server 2>/dev/null || true
sudo pkill -9 redis-server 2>/dev/null || true
sleep 2

# Backup original Redis configuration
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup 2>/dev/null || true

# Configure Redis - DISABLE AOF, USE ONLY RDB for reliability
sudo tee /etc/redis/redis.conf > /dev/null << 'EOF'
# Redis configuration optimized for stateful storage
# Using RDB-only persistence to avoid AOF timing issues

# Network Configuration
bind 0.0.0.0
port 6379
protected-mode yes
timeout 0
tcp-keepalive 300

# Use stateful storage directory (on data disk)
dir /share/redis

# RDB Persistence settings (snapshots)
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb

# DISABLE AOF to avoid read-only filesystem issues during startup
appendonly no

# Memory and performance optimizations
maxmemory-policy allkeys-lru
tcp-backlog 511
databases 16

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log
EOF

# Set correct ownership and permissions for config file
sudo chown redis:redis /etc/redis/redis.conf
sudo chmod 640 /etc/redis/redis.conf

echo "✅ Redis configuration file created (RDB-only persistence)"

# Create systemd override for proper startup order and delays
sudo mkdir -p /etc/systemd/system/redis-server.service.d/
sudo tee /etc/systemd/system/redis-server.service.d/override.conf > /dev/null << 'EOF'
[Unit]
After=share.mount network-online.target
Requires=share.mount
StartLimitBurst=10
StartLimitIntervalSec=300

[Service]
# Add delay to ensure filesystem is fully ready
ExecStartPre=/bin/sleep 10

# Ensure we're running as redis user
User=redis
Group=redis

# Restart on failure with longer intervals
Restart=on-failure
RestartSec=10s

# Increase timeouts
TimeoutStartSec=120s
TimeoutStopSec=60s
EOF

echo "✅ Redis systemd override created"

# Reload systemd configuration
sudo systemctl daemon-reload
sudo systemctl enable redis-server

echo "Starting Redis server..."

# Final filesystem verification
sudo mount -o remount,rw $MNT_DIR
sleep 2

# Final permission check
sudo chown -R redis:redis "$REDIS_DATA_DIR"
sudo chmod 770 "$REDIS_DATA_DIR"

# Start Redis - let systemd handle retries
sudo systemctl start redis-server

# Wait for Redis to stabilize
sleep 12

# Check Redis status
REDIS_STARTED=false
if sudo systemctl is-active --quiet redis-server; then
    REDIS_STARTED=true
    echo "✅ Redis started successfully"
else
    echo "⚠️ Redis is still starting (systemd will retry automatically)"
    # Give it more time
    sleep 10
    if sudo systemctl is-active --quiet redis-server; then
        REDIS_STARTED=true
        echo "✅ Redis started successfully after additional wait"
    fi
fi

# Final status check and reporting
echo ""
echo "=========================================="
echo "Redis Status Check"
echo "=========================================="

if [ "$REDIS_STARTED" = true ]; then
    echo "✅ Redis is running successfully on STATEFUL storage"
    echo "📁 Redis data directory: $REDIS_DATA_DIR"
    echo ""
    echo "📊 Redis Server Info:"
    redis-cli ping 2>/dev/null || echo "⚠️ Redis ping failed (still starting)"
    redis-cli config get dir 2>/dev/null || true
    echo ""
    echo "💾 Redis Persistence:"
    redis-cli config get save 2>/dev/null || true
    redis-cli config get appendonly 2>/dev/null || true
else
    echo "⚠️ Redis is still initializing - systemd will continue retry attempts"
    echo "   Check status with: sudo systemctl status redis-server"
    echo ""
    echo "📋 Recent Redis logs:"
    sudo journalctl -u redis-server --no-pager -n 30
fi

echo "=========================================="

#########################################################################
# Final Summary
#########################################################################

echo ""
echo "=========================================="
echo "🎉 Startup Script Completed!"
echo "=========================================="
echo ""
echo "📁 NFS Configuration:"
echo "   - Mount point: $MNT_DIR"
echo "   - Mount options: $(mount | grep $MNT_DIR | awk '{print $6}')"
echo "   - NFS exports: $(sudo exportfs | wc -l) active"
echo "   - Disk usage: $(df -h $MNT_DIR | tail -1 | awk '{print $5}')"
echo ""
echo "🔴 Redis Configuration:"
echo "   - Data directory: $REDIS_DATA_DIR (STATEFUL storage)"
echo "   - Directory permissions: $(ls -ld $REDIS_DATA_DIR 2>/dev/null | awk '{print $1, $3, $4}' || echo 'checking...')"
echo "   - Status: $(sudo systemctl is-active redis-server 2>/dev/null || echo 'starting')"
echo "   - Port: 6379"
echo "   - Persistence: RDB snapshots only (AOF disabled for reliability)"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "   - Redis data is stored on STATEFUL disk (survives reboots)"
echo "   - Using RDB-only persistence for filesystem compatibility"
echo "   - Snapshots occur: every 15min (if 1+ change), 5min (if 10+ changes), 1min (if 10k+ changes)"
echo "   - NFS share is available for file sharing"
echo ""
echo "🔗 Connection Info:"
echo "   - NFS: mount this server at /share"
echo "   - Redis: connect to $(hostname -I | awk '{print $1}'):6379"
echo ""
echo "=========================================="
