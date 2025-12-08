#!/bin/bash
set -euo pipefail

# -------------------------
# Install updates + Docker
# -------------------------
apt-get update -y
apt-get install -y docker.io docker-compose-plugin awscli

systemctl enable --now docker

# -------------------------
# Format + mount EBS volumes
# -------------------------
mkfs -t ext4 ${config_volume}
mkfs -t ext4 ${library_volume}

mkdir -p /config
mkdir -p /library

echo "${config_volume} /srv/config ext4 defaults,nofail 0 2" >> /etc/fstab
echo "${library_volume} /srv/library ext4 defaults,nofail 0 2" >> /etc/fstab

mount -a

# -------------------------
# Pull cweb setup files from S3
# -------------------------
mkdir -p /srv/cweb
aws s3 sync s3://${setup_bucket} /srv/cweb-setup

cd /srv/cweb-setup

# -------------------------
# Set initial Calibre-Web admin password
# -------------------------
docker compose run --rm calibre-web bash -c "calibre-web -s ${admin_user}:${admin_pass}"

# -------------------------
# Start services
# -------------------------
docker compose up -d