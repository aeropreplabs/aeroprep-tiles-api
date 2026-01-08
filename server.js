import express from "express";
import fs from "fs/promises";
import path from "path";

const app = express();

// -----------------------------------------------------------------------------
// Tile storage
// Render persistent disk is mounted at /var/data
// Tiles live at: /var/data/tiles/chicago/{z}/{x}/{y}.png
// -----------------------------------------------------------------------------
const TILES_ROOT = "/var/data/tiles";

// -----------------------------------------------------------------------------
// CORS
// Local dev (Vite) runs at http://localhost:5173 and will be blocked unless
// the tiles API sends Access-Control-Allow-Origin.
// Add your production frontend origin here later (Render static site / custom domain).
// -----------------------------------------------------------------------------
const ALLOWED_ORIGINS = new Set([
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  // Example (add later when you have it):
  // "https://app.aeropreplabs.com",
]);

app.use((req, res, next) => {
  const origin = req.headers.origin;

  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  }

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }

  next();
});

// -----------------------------------------------------------------------------
// Root + health check
// -----------------------------------------------------------------------------
app.get("/", (_req, res) => {
  res.status(200).send("ok");
});

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// -----------------------------------------------------------------------------
// Tile endpoint with XYZ -> TMS fallback
// Leaflet requests XYZ tiles: /{z}/{x}/{y}.png
// Many generators produce TMS tiles where Y is flipped.
// If XYZ path 404s, try TMS:
//   y_tms = (2^z - 1 - y_xyz)
// -----------------------------------------------------------------------------
app.get("/tiles/:chartId/:z/:x/:y.png", async (req, res) => {
  const { chartId, z, x, y } = req.params;

  const Z = Number(z);
  const X = Number(x);
  const Y = Number(y);

  if (![Z, X, Y].every(Number.isInteger) || Z < 0 || X < 0 || Y < 0) {
    return res.status(400).send("Invalid tile coordinates");
  }

  const xyzPath = path.join(TILES_ROOT, chartId, String(Z), String(X), `${Y}.png`);

  const yTms = (2 ** Z - 1 - Y);
  const tmsPath = path.join(TILES_ROOT, chartId, String(Z), String(X), `${yTms}.png`);

  try {
    let filePath = xyzPath;

    // Prefer XYZ if it exists, otherwise try TMS
    try {
      await fs.access(xyzPath);
    } catch {
      await fs.access(tmsPath);
      filePath = tmsPath;
    }

    const data = await fs.readFile(filePath);

    res.setHeader("Content-Type", "image/png");
    res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
    return res.status(200).send(data);
  } catch {
    return res.status(404).end();
  }
});

// -----------------------------------------------------------------------------
// Start server (Render injects PORT)
// -----------------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Sectional tile API listening on port ${PORT}`);
});
