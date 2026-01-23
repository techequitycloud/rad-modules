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

# Setup local disk for NFS share
DISK_ID=/dev/sdb
MNT_DIR=/share
sudo mkdir -p $MNT_DIR
if [[ $(lsblk $DISK_ID -no fstype) != 'ext4' ]]; then
    sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard $DISK_ID
else
    sudo e2fsck -fp $DISK_ID
    sudo resize2fs $DISK_ID
fi
if [[ ! $(grep -qs "$MNT_DIR " /proc/mounts) ]]; then
    if [[ ! $(grep -qs "$MNT_DIR " /etc/fstab) ]]; then
        UUID=$(blkid -s UUID -o value $DISK_ID)
        sudo grep -qxF "UUID=$UUID $MNT_DIR ext4 rw,discard,defaults,nofail 0 2" /etc/fstab || echo "UUID=$UUID $MNT_DIR ext4 rw,discard,defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo systemctl daemon-reload
    sudo mount $MNT_DIR
    sudo chmod a+w $MNT_DIR
fi

# NFS Configuration (for shared storage)
sudo sed -i 's/^STATDOPTS=.*/STATDOPTS="-p 2046"/' /etc/default/nfs-common
sudo touch /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_tcpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_tcpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_udpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_udpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf

# Set permissions for NFS share, excluding 'redis' directory if it exists
# This prevents overwriting Redis permissions on reboot
sudo chown nobody:nogroup "$MNT_DIR"
sudo chmod 775 "$MNT_DIR"
# Apply recursively only to files/dirs that are NOT 'redis'
sudo find "$MNT_DIR" -mindepth 1 -maxdepth 1 -not -name 'redis' -exec chown -R nobody:nogroup {} +
sudo find "$MNT_DIR" -mindepth 1 -maxdepth 1 -not -name 'redis' -exec chmod -R 775 {} +

sudo chmod 777 /etc/exports
# sudo grep -qxF '/share *(rw,sync,all_squash,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,all_squash,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null # Use this option to disallow root priviledges
sudo grep -qxF '/share *(rw,sync,no_root_squash,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_root_squash,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null
sudo systemctl restart nfs-kernel-server
sudo exportfs

# Configure Redis to use STATEFUL STORAGE (on NFS disk)
echo "Configuring Redis for optimal performance on stateful storage..."

# Create Redis data directory on STATEFUL filesystem (NFS disk)
REDIS_DATA_DIR="$MNT_DIR/redis"
sudo mkdir -p "$REDIS_DATA_DIR"
sudo chown redis:redis "$REDIS_DATA_DIR"
sudo chmod 755 "$REDIS_DATA_DIR"

# Stop Redis before configuration changes
sudo systemctl stop redis-server

# Backup original Redis configuration
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

# Configure Redis for optimal local storage performance
sudo tee /etc/redis/redis.conf.local > /dev/null << 'EOF'
# Redis configuration optimized for stateful storage
bind 0.0.0.0
port 6379
timeout 0
tcp-keepalive 300

# Use stateful storage directory (on data disk)
dir /share/redis

# Persistence settings optimized for local disk
save 900 1
save 300 10  
save 60 10000

# AOF settings for better durability on local storage
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Memory and performance optimizations
maxmemory-policy allkeys-lru
tcp-backlog 511
databases 16

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Security
protected-mode no
EOF

# Replace the Redis configuration
sudo mv /etc/redis/redis.conf.local /etc/redis/redis.conf

# Create log directory
sudo mkdir -p /var/log/redis
sudo chown redis:redis /var/log/redis

# Enable and start Redis
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Wait for Redis to start
sleep 3

# Verify Redis is running and using correct directory
if sudo systemctl is-active --quiet redis-server; then
    echo "✅ Redis is running successfully on STATEFUL storage"
    echo "📁 Redis data directory: $REDIS_DATA_DIR"
    echo "📊 Redis info:"
    redis-cli info server | grep redis_version
    redis-cli config get dir
    echo "🔧 Redis memory usage:"
    redis-cli info memory | grep used_memory_human
else
    echo "❌ Redis failed to start"
    echo "📋 Redis logs:"
    sudo journalctl -u redis-server --no-pager -n 10
fi

echo ""
echo "🎉 Startup script completed successfully!"
echo "📁 NFS share directory: $MNT_DIR (for shared files)"
echo "🔴 Redis data directory: $REDIS_DATA_DIR (STATEFUL storage)"
echo "🟢 Redis status: $(sudo systemctl is-active redis-server)"
echo ""
echo "⚠️  IMPORTANT: Redis is using STATEFUL storage"
echo "   - Redis data: $REDIS_DATA_DIR (data disk)"
echo "   - Shared files: $MNT_DIR (NFS for file sharing)"
