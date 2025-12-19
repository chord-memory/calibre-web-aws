#!/bin/bash
set -euo pipefail

# -------------------------
# Install updates + Docker
# -------------------------
apt-get update -y
apt-get install -y docker.io docker-compose awscli sqlite3

systemctl enable --now docker

# -------------------------
# Format + mount EBS volumes
# -------------------------
CONFIG_VOLUME_ID="${config_vol_nodash}"
INGEST_VOLUME_ID="${ingest_vol_nodash}"
LIBRARY_VOLUME_ID="${lib_vol_nodash}"

CONFIG_MOUNT=/srv/config
INGEST_MOUNT=/srv/ingest
LIBRARY_MOUNT=/srv/library

mount_volume() {
    local VOL_ID=$1
    local MOUNT=$1

    DEVICE=$(readlink -f "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${VOL_ID}")

    # Only format if no filesystem exists
    if ! blkid $DEVICE; then
        mkfs -t ext4 $DEVICE
    fi

    mkdir -p $MOUNT

    DEVICE_UUID=$(blkid -s UUID -o value $DEVICE)

    FSTAB="UUID=$DEVICE_UUID $MOUNT ext4 defaults,nofail 0 2"

    grep -qxF "$FSTAB" || echo "$FSTAB" >> /etc/fstab
}

mount_volume $CONFIG_VOLUME_ID $CONFIG_MOUNT
mount_volume $INGEST_VOLUME_ID $INGEST_MOUNT
mount_volume $LIBRARY_VOLUME_ID $LIBRARY_MOUNT

mount -a

chown -R 1000:1000 $CONFIG_MOUNT
chown -R 1000:1000 $INGEST_MOUNT
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