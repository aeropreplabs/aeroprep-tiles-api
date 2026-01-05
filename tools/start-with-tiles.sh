#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/data/tiles

if [ -z "${TILES_TARBALL_URL:-}" ]; then
  echo "ERROR: TILES_TARBALL_URL is not set."
  exit 1
fi

# If zoom 13 exists, assume tiles are present
if [ ! -d /var/data/tiles/chicago/13 ]; then
  echo "Tiles not found on disk. Downloading..."
  curl -L "$TILES_TARBALL_URL" -o /var/data/chicago-tiles.tar.gz

  echo "Extracting tiles..."
  tar -xzf /var/data/chicago-tiles.tar.gz -C /var/data/tiles

  rm -f /var/data/chicago-tiles.tar.gz
  echo "Tiles install complete."
else
  echo "Tiles already present on disk. Skipping download."
fi

exec node server.js
