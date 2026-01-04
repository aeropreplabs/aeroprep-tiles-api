import express from "express";
import path from "path";
import MBTiles from "@mapbox/mbtiles";

const app = express();

// IMPORTANT: this must match your Render disk mount
const MBTILES_DIR = "/var/data/sectionals";

// Cache opened MBTiles handles
const openHandles = new Map();

function openMbtiles(chartId) {
  if (openHandles.has(chartId)) return openHandles.get(chartId);

  const mbtilesPath = path.join(MBTILES_DIR, `${chartId}.mbtiles`);

  const p = new Promise((resolve, reject) => {
    new MBTiles(`${mbtilesPath}?mode=ro`, (err, mbtiles) => {
      if (err) return reject(err);
      resolve(mbtiles);
    });
  });

  openHandles.set(chartId, p);
  return p;
}

// Health check (so Render can tell it's alive)
app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// Tile endpoint
app.get("/api/sectionals/:chartId/tiles/:z/:x/:y.png", async (req, res) => {
  const { chartId, z, x, y } = req.params;
  const Z = Number(z);
  const X = Number(x);
  const Y = Number(y);

  if (![Z, X, Y].every(Number.isInteger)) {
    return res.status(400).send("Invalid tile coordinates");
  }

  // Flip Y: XYZ (web) → TMS (MBTiles)
  const yForDb = (2 ** Z - 1 - Y);

  try {
    const mbtiles = await openMbtiles(chartId);

    mbtiles.getTile(Z, X, yForDb, (err, data) => {
      if (err || !data) {
        return res.status(204).end();
      }

      res.setHeader("Content-Type", "image/png");
      res.setHeader("Cache-Control", "public, max-age=86400, immutable");
      res.send(data);
    });
  } catch (e) {
    res.status(404).send("Sectional not found");
  }
});

// Render provides PORT
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Tile API listening on ${PORT}`);
});
