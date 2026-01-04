FROM node:20-bookworm

# Install system deps:
# - gdal-bin (GeoTIFF → MBTiles)
# - python-is-python3 (provides `python` for node-gyp/sqlite3)
RUN apt-get update && apt-get install -y \
    gdal-bin \
    python-is-python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"]