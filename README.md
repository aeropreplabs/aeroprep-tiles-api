# AeroPrep Labs – Sectional Tile Builder

This repository contains the tooling used to generate and serve FAA sectional chart tiles for AeroPrep Labs.

The intent is **not** to build a general-purpose map product. These tiles exist solely to support focused, examiner-style oral exam questions that reference a representative sectional chart.

At this stage, **only the Chicago sectional** is used by design.

---

## What this repo does

- Downloads FAA sectional data (ZIP or local GeoTIFF)
- Converts palette-based GeoTIFFs to RGBA
- Reprojects charts to Web Mercator (EPSG:3857)
- Builds internal overviews (pyramids)
- Generates `{z}/{x}/{y}.png` map tiles capped at zoom level 13
- Produces static assets suitable for fast, cacheable serving

All heavy geospatial processing is done **locally**, not in production.

---

## What this repo intentionally does NOT do

- It does not store generated tiles in git
- It does not run GDAL in production containers
- It does not provide a chart selector or map browser
- It does not attempt full U.S. sectional coverage

Tiles are treated as **build artifacts**, not source code.

---

## Prerequisites

You must have the following installed locally:

- macOS or Linux
- Homebrew (macOS)
- GDAL (installed at the system/user level)

Install GDAL on macOS:

```bash
brew install gdal
