const path = require("path");
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config({ path: path.join(__dirname, ".env") });

const app = express();

app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Private-Network", "true");
  next();
});

app.use(
  cors({
    origin: true,
    methods: ["GET", "HEAD", "PUT", "PATCH", "POST", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "Accept",
      "Origin",
      "X-Requested-With",
      "X-Idempotency-Key",
    ],
    optionsSuccessStatus: 204,
  })
);
app.use(express.json());

app.use((req, res, next) => {
  console.log(`[REQ] ${req.method} ${req.url}`);
  next();
});

const elderController = require("./controllers/elderController");
const readingRoutes = require("./routes/readingRoutes");
const elderRoutes = require("./routes/elderRoutes");
const medicineRoutes = require("./routes/medicineRoutes");
const heartAlertRoutes = require("./routes/heartAlertRoutes");
const musicSessionRoutes = require("./routes/musicSessionRoutes");
const musicRoutes = require("./routes/musicRoutes");
const musicController = require("./controllers/musicController");
const { processMedicineEventsBatch } = require("./services/medicineEventOutbox");

app.get("/health", (req, res) => {
  res.status(200).type("text/plain").send("ok");
});

/** JSON probe: confirms this process is ElderLink (not some other app on :5000). */
app.get("/api/backend-info", (req, res) => {
  res.status(200).json({
    ok: true,
    service: "elderlink",
    purgeProbeGet: "/api/purge-elder",
    purgePostPaths: [
      "/api/purge-elder",
      "/api/purge_elder",
      "/api/elders/purge",
      "/api/readings/admin/purge-elder",
      "/api/readings/admin/purgeelder",
    ],
    musicStaleCleanupPost: "/api/music-sessions/admin/close-stale",
    medicineEventsProcessPost: "/api/medicine-events/process",
  });
});

app.get("/api/purge-elder", (req, res) => {
  res.status(200).json({
    ok: true,
    message: "ElderLink purge endpoint is installed. Use POST with JSON body: { elderName, elderId? }.",
    postPaths: [
      "/api/purge-elder",
      "/api/purge_elder",
      "/api/elders/purge",
      "/api/readings/admin/purge-elder",
      "/api/readings/admin/purgeelder",
    ],
  });
});
app.post("/api/purge-elder", elderController.purgeElderData);
// No-hyphen aliases (avoids rare clients/proxies mangling paths around `-`)
app.post("/api/purge_elder", elderController.purgeElderData);
app.post("/api/elders/purge", elderController.purgeElderData);
app.post("/api/readings/admin/purge-elder", elderController.purgeElderData);
app.post("/api/readings/admin/purgeelder", elderController.purgeElderData);

/** Drain MedicineEvents outbox (async notify). Optional: Authorization: Bearer <ELDERLINK_PROCESS_EVENTS_KEY> */
app.post("/api/medicine-events/process", async (req, res) => {
  const key = process.env.ELDERLINK_PROCESS_EVENTS_KEY;
  if (key && req.get("Authorization") !== `Bearer ${key}`) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  try {
    const lim = Math.min(Number(req.query.limit) || 100, 500);
    const drained = await processMedicineEventsBatch(lim);
    return res.status(200).json({ ok: true, drained });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
});

app.use("/api/readings", readingRoutes);
app.use("/api/elders", elderRoutes);
app.use("/api/medicines", medicineRoutes);
app.use("/api/heart-alert", heartAlertRoutes);
app.use("/api/music", musicRoutes);
app.use("/api/music-sessions", musicSessionRoutes);

mongoose
  .connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 30000,
    socketTimeoutMS: 45000,
    connectTimeoutMS: 30000,
    maxPoolSize: 10,
    retryWrites: true,
    w: "majority",
  })
  .then(() => {
    console.log("✅ MongoDB connected successfully");

    const PORT = Number(process.env.PORT) || 5000;
    app.listen(PORT, "0.0.0.0", () => {
      console.log("🔥 ElderLink backend running with PURGE ROUTES ACTIVE");
      console.log(`Server running on port ${PORT}`);
      setInterval(() => {
        musicController.runMusicStaleCleanup().catch((e) =>
          console.error("runMusicStaleCleanup:", e)
        );
      }, 60_000);
      setTimeout(() => {
        musicController.runMusicStaleCleanup().catch((e) =>
          console.error("runMusicStaleCleanup (startup):", e)
        );
      }, 5_000);
      setInterval(() => {
        processMedicineEventsBatch(80).catch((e) =>
          console.error("processMedicineEventsBatch:", e)
        );
      }, 5_000);
      setTimeout(() => {
        processMedicineEventsBatch(80).catch((e) =>
          console.error("processMedicineEventsBatch (startup):", e)
        );
      }, 2_000);
    });
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err.message);
    console.error("Full error:", err);
    console.error("Server will not start without database connection");
    process.exit(1);
  });
