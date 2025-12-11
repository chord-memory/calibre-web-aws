#!/bin/bash
set -euo pipefail

# -------------------------
# Install updates + Docker
# -------------------------
apt-get update -y
apt-get install -y docker.io docker-compose awscli

systemctl enable --now docker

# -------------------------
# Format + mount EBS volumes
# -------------------------
CONFIG_DEVICE=$(readlink -f "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${config_vol_nodash}")
LIB_DEVICE=$(readlink -f "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${lib_vol_nodash}")

# Only format if no filesystem exists
if ! blkid $CONFIG_DEVICE; then
    mkfs -t ext4 $CONFIG_DEVICE
fi

if ! blkid $LIB_DEVICE; then
    mkfs -t ext4 $LIB_DEVICE
fi

CONFIG_MOUNT=/srv/config
LIBRARY_MOUNT=/srv/library

mkdir -p $CONFIG_MOUNT $LIBRARY_MOUNT

CONFIG_UUID=$(blkid -s UUID -o value $CONFIG_DEVICE)
LIB_UUID=$(blkid -s UUID -o value $LIB_DEVICE)

CONFIG_FSTAB="UUID=$CONFIG_UUID $CONFIG_MOUNT ext4 defaults,nofail 0 2"
LIB_FSTAB="UUID=$LIB_UUID $LIBRARY_MOUNT ext4 defaults,nofail 0 2"

grep -qxF "$CONFIG_FSTAB" || echo "$CONFIG_FSTAB" >> /etc/fstab
grep -qxF "$LIB_FSTAB" || echo "$LIB_FSTAB" >> /etc/fstab

mount -a

chown -R 1000:1000 $CONFIG_MOUNT
chown -R 1000:1000 $LIBRARY_MOUNT

# -------------------------
# Pull cweb setup files from S3
# -------------------------
SETUP_MOUNT=/srv/cweb-setup

mkdir -p $SETUP_MOUNT
aws s3 sync s3://${setup_bucket} $SETUP_MOUNT

cd $SETUP_MOUNT

# -------------------------
# Set initial Calibre-Web admin password
# -------------------------
docker-compose run --rm calibre-web bash -c "python3 /app/calibre-web/cps.py -p /config/app.db -s ${admin_user}:${admin_pass}"

# -------------------------
# Start services
# -------------------------
docker-compose up -d