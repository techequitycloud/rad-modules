#!/bin/bash 
#
# Copyright 2024 Tech Equity Ltd
#
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

sudo apt-get update && sudo apt install -y -q nfs-kernel-server unzip postgresql-client-16 zip
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