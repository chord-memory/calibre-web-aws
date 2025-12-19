#!/usr/bin/env bash
set -euo pipefail

source .env

REPO_DIR="../calibre-web-automated"
REPO_URL="https://github.com/crocodilestick/Calibre-Web-Automated.git"

# Clone only if it doesn't exist
if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

git checkout main
git pull origin main

VERSION=$(git rev-parse --short HEAD)
DATE=$(date -u '+%Y-%m-%d %H:%M UTC')

docker build \
  --build-arg BUILD_DATE="$DATE" \
  --build-arg VERSION="main-$VERSION" \
  --label "org.opencontainers.image.source=https://github.com/chord-memory/calibre-web-aws" \
  -t calibre-web-automated:local .

docker tag calibre-web-automated:local \
  ghcr.io/chord-memory/calibre-web-automated:main
docker tag calibre-web-automated:local \
  ghcr.io/chord-memory/calibre-web-automated:main-$VERSION

echo $GHCR_PAT | docker login ghcr.io -u chord-memory --password-stdin

docker push ghcr.io/chord-memory/calibre-web-automated:main
docker push ghcr.io/chord-memory/calibre-web-automated:main-$VERSION