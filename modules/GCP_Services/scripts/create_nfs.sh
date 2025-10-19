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

sudo apt-get update >/dev/null && sudo apt install -y -q nfs-kernel-server python3 python3-pip unzip wget curl postgresql-client-16 mysql-client zip >/dev/null

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
sudo sed -i 's/^STATDOPTS=.*/STATDOPTS="-p 2046"/' /etc/default/nfs-common
sudo touch /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_tcpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_tcpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf
sudo grep -qxF "options lockd nlm_udpport=4045" /etc/modprobe.d/lock.conf || echo "options lockd nlm_udpport=4045" | sudo tee -a /etc/modprobe.d/lock.conf
sudo chmod -R 775 $MNT_DIR
sudo chown -R nobody:nogroup $MNT_DIR
sudo chmod 755 /etc/exports
# sudo grep -qxF '/share *(rw,sync,all_squash,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,all_squash,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null # Use this option to disallow root priviledges 
sudo grep -qxF '/share *(rw,sync,no_root_squash,no_subtree_check)' /etc/exports || echo '/share *(rw,sync,no_root_squash,no_subtree_check)' | sudo tee -a /etc/exports > /dev/null
sudo systemctl restart nfs-kernel-server
sudo exportfs