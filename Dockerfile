# ------------------------------------------------------------
# AeroPrep Tiles API Dockerfile
# ------------------------------------------------------------

# Use a stable Node LTS image (Debian-based)
FROM node:20-slim

# Set working directory
WORKDIR /app

# Install runtime dependencies needed for tile bootstrap
# - curl: download tile tarball
# - ca-certificates: TLS sanity
# tar is already present in slim images
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy package files first (better layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install --omit=dev

# Copy application source
COPY . .

# Ensure startup script is executable
RUN chmod +x tools/start-with-tiles.sh

# Expose whatever port your server listens on
# (Render injects PORT env var automatically)
EXPOSE 3000

# ------------------------------------------------------------
# Start command:
# - Ensure tiles exist on persistent disk
# - Download & extract if missing
# - Start Node server
# ------------------------------------------------------------
CMD ["/app/tools/start-with-tiles.sh"]
