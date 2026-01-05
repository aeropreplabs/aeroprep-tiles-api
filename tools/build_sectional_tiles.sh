#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# build_sectional_tiles.sh
#
# Accepts:
#   - Local GeoTIFF (.tif)
#   - OR direct URL to a ZIP containing a GeoTIFF
#
# Pipeline:
#   1) Download ZIP (if URL)
#   2) Extract GeoTIFF
#   3) Expand palette -> RGBA
#   4) Reproject to EPSG:3857
#   5) Build overviews
#   6) Generate tiles (zmin–13)
#
# Usage:
#   ./build_sectional_tiles.sh <input_path_or_zip_url> <slug> [zmin]
#
# Examples:
#   ./build_sectional_tiles.sh \
#     https://aeronav.faa.gov/visual/11-27-2025/sectional-files/Chicago.zip \
#     chicago
#
#   ./build_sectional_tiles.sh \
#     "/path/to/Chicago SEC.tif" \
#     chicago 6
# ------------------------------------------------------------

INPUT="${1:-}"
SLUG="${2:-}"
ZMIN="${3:-6}"
ZMAX="13"

if [[ -z "${INPUT}" || -z "${SLUG}" ]]; then
  echo "Usage: $0 <input_tif_or_zip_url> <slug> [zmin]"
  exit 1
fi

if ! [[ "${ZMIN}" =~ ^[0-9]+$ ]]; then
  echo "Error: zmin must be an integer"
  exit 1
fi
if (( ZMIN > ZMAX )); then
  echo "Error: zmin (${ZMIN}) cannot be greater than zmax (${ZMAX})"
  exit 1
fi

# ---- Tool checks ----
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: Required command not found: $1"
    exit 1
  }
}

need_cmd curl
need_cmd unzip
need_cmd gdalinfo
need_cmd gdal_translate
need_cmd gdalwarp
need_cmd gdaladdo

GDAL2TILES=""
if command -v gdal2tiles.py >/dev/null 2>&1; then
  GDAL2TILES="gdal2tiles.py"
elif command -v gdal2tiles >/dev/null 2>&1; then
  GDAL2TILES="gdal2tiles"
else
  echo "Error: gdal2tiles(.py) not found"
  exit 1
fi

# ---- Paths ----
ROOT_DIR="$(pwd)"
WORK_DIR="${ROOT_DIR}/_geotiff_work/${SLUG}"
SRC_DIR="${WORK_DIR}/source"
DL_DIR="${WORK_DIR}/download"
WARP_DIR="${WORK_DIR}/warped"
LOG_DIR="${WORK_DIR}/logs"
TILES_DIR="${ROOT_DIR}/tiles/${SLUG}"

mkdir -p "${SRC_DIR}" "${DL_DIR}" "${WARP_DIR}" "${LOG_DIR}" "${TILES_DIR}"

# ---- Resolve input ----
SRC_TIF=""

if [[ "${INPUT}" =~ ^https?://.*\.zip$ ]]; then
  echo "=== Detected ZIP URL ==="

  ZIP_FILE="${DL_DIR}/source.zip"
  EXTRACT_DIR="${DL_DIR}/unzipped"

  mkdir -p "${EXTRACT_DIR}"

  if [[ ! -f "${ZIP_FILE}" ]]; then
    echo "Downloading ZIP..."
    curl -L "${INPUT}" -o "${ZIP_FILE}"
  else
    echo "ZIP already downloaded, skipping"
  fi

  echo "Extracting ZIP..."
  unzip -o "${ZIP_FILE}" -d "${EXTRACT_DIR}" >/dev/null

  echo "Searching for GeoTIFF..."
  SRC_TIF="$(find "${EXTRACT_DIR}" -type f \( -iname '*.tif' -o -iname '*.tiff' \) | head -n 1)"

  if [[ -z "${SRC_TIF}" ]]; then
    echo "Error: No GeoTIFF found inside ZIP"
    exit 1
  fi

elif [[ -f "${INPUT}" ]]; then
  SRC_TIF="${INPUT}"
else
  echo "Error: Input must be a local .tif or a ZIP URL"
  exit 1
fi

# ---- Copy source into working dir ----
FINAL_SRC_TIF="${SRC_DIR}/$(basename "${SRC_TIF}")"
if [[ ! -f "${FINAL_SRC_TIF}" ]]; then
  echo "Copying source GeoTIFF into working directory..."
  cp -v "${SRC_TIF}" "${FINAL_SRC_TIF}"
else
  echo "Source already present: ${FINAL_SRC_TIF}"
fi

echo ""
echo "=== GDAL version ==="
gdalinfo --version

echo ""
echo "=== Inspect input GeoTIFF ==="
gdalinfo "${FINAL_SRC_TIF}" | tee "${LOG_DIR}/gdalinfo_input.txt" >/dev/null

# ---- Step 1: Expand palette ----
RGBA_TIF="${WARP_DIR}/${SLUG}_rgba.tif"
if [[ ! -f "${RGBA_TIF}" ]]; then
  echo ""
  echo "=== Expanding color table to RGBA ==="
  gdal_translate \
    -expand rgba \
    "${FINAL_SRC_TIF}" \
    "${RGBA_TIF}" \
    2>&1 | tee "${LOG_DIR}/01_translate_rgba.log"
fi

# ---- Step 2: Reproject ----
MERC_TIF="${WARP_DIR}/${SLUG}_3857.tif"
if [[ ! -f "${MERC_TIF}" ]]; then
  echo ""
  echo "=== Reprojecting to EPSG:3857 ==="
  gdalwarp \
    -t_srs EPSG:3857 \
    -r near \
    -multi \
    -wo NUM_THREADS=ALL_CPUS \
    -co TILED=YES \
    -co COMPRESS=DEFLATE \
    -co NUM_THREADS=ALL_CPUS \
    -co BIGTIFF=IF_SAFER \
    "${RGBA_TIF}" \
    "${MERC_TIF}" \
    2>&1 | tee "${LOG_DIR}/02_warp_3857.log"
fi

echo ""
echo "=== Inspect warped output ==="
gdalinfo "${MERC_TIF}" | tee "${LOG_DIR}/gdalinfo_3857.txt" >/dev/null

# ---- Step 3: Overviews ----
echo ""
echo "=== Building overviews ==="
gdaladdo \
  -r nearest \
  --config COMPRESS_OVERVIEW DEFLATE \
  --config NUM_THREADS ALL_CPUS \
  "${MERC_TIF}" \
  2 4 8 16 32 64 \
  2>&1 | tee "${LOG_DIR}/03_overviews.log"

# ---- Step 4: Tiles ----
echo ""
echo "=== Generating tiles z${ZMIN}-${ZMAX} ==="
rm -rf "${TILES_DIR:?}/"*

"${GDAL2TILES}" \
  -z "${ZMIN}-${ZMAX}" \
  -r near \
  -w none \
  "${MERC_TIF}" \
  "${TILES_DIR}" \
  2>&1 | tee "${LOG_DIR}/04_gdal2tiles.log"

echo ""
echo "✅ Done"
echo "Tiles: ${TILES_DIR}/{z}/{x}/{y}.png"
echo "Logs: ${LOG_DIR}"

SAMPLE_TILE="$(find "${TILES_DIR}" -type f -name '*.png' | head -n 1 || true)"
if [[ -n "${SAMPLE_TILE}" ]]; then
  echo "Sample tile: ${SAMPLE_TILE}"
fi
