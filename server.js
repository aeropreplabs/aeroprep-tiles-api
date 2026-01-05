import express from "express";
import path from "path";

const app = express();

// -----------------------------------------------------------------------------
// Tile storage
// Render persistent disk is mounted at /var/data
// Tiles live at: /var/data/tiles/chicago/{z}/{x}/{y}.png
// -----------------------------------------------------------------------------
const TILES_ROOT = "/var/data/tiles";

// -----------------------------------------------------------------------------
// Health check (Render uses this to verify the service is alive)
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Optional: explicit 404 handler for missing tiles
// (keeps logs cleaner than Express default HTML response)
// -----------------------------------------------------------------------------
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
