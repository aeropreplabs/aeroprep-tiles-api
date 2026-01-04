cat > Dockerfile <<'EOF'
FROM node:20-bookworm

# Install GDAL tools (for GeoTIFF -> MBTiles conversion)
RUN apt-get update && apt-get install -y \
  gdal-bin \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy the rest of the app
COPY . .

ENV NODE_ENV=production
EXPOSE 3000

CMD ["npm", "start"]
EOF
