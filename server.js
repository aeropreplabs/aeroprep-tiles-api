import express from "express";

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

  // Only set CORS headers for allowed browser origins
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  }

  // Handle preflight requests
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
// Serve sectional tiles as static assets
// URL format:
//   /tiles/chicago/{z}/{x}/{y}.png
// -----------------------------------------------------------------------------
app.use(
  "/tiles",
  express.static(TILES_ROOT, {
    maxAge: "365d",
    immutable: true,
    setHeaders: (res) => {
      res.setHeader("Content-Type", "image/png");
    },
  })
);

// Clean 404 for missing tiles
app.use("/tiles", (_req, res) => {
  res.status(404).end();
});

// -----------------------------------------------------------------------------
// Start server (Render injects PORT)
// -----------------------------------------------------------------------------
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Sectional tile API listening on port ${PORT}`);
});
