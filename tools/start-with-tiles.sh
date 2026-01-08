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

  # ---- Normalize folder layout ----
  # If archive was created as tiles/chicago/... it will land in /var/data/tiles/tiles/chicago/...
  if [ -d /var/data/tiles/tiles/chicago ] && [ ! -d /var/data/tiles/chicago ]; then
    echo "Normalizing tile folder layout (/var/data/tiles/tiles/chicago -> /var/data/tiles/chicago)..."
    mkdir -p /var/data/tiles/chicago
    mv /var/data/tiles/tiles/chicago/* /var/data/tiles/chicago/ || true
    rm -rf /var/data/tiles/tiles
  fi

  # Sanity check
  if [ ! -d /var/data/tiles/chicago/13 ]; then
    echo "ERROR: Tiles extraction completed but /var/data/tiles/chicago/13 not found."
    echo "Contents of /var/data/tiles:"
    ls -lah /var/data/tiles | head -n 200
    exit 1
  fi

  echo "Tiles install complete."
else
  echo "Tiles already present on disk. Skipping download."
fi

exec node server.js
