const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const dns = require("dns").promises;
require("dotenv").config();

// ----- DIAGNOSTIC SNIPPET (remove after debugging) -----
(async () => {
  const uri = process.env.MONGO_URI || "";
  const match = uri.match(/@([^/?#]+)/);
  const host = match ? match[1] : "(could not parse host)";
  const srvHost = "_mongodb._tcp." + host;
  console.log("[DIAG] MONGO_URI present:", !!uri);
  console.log("[DIAG] Host from URI:", host);
  console.log("[DIAG] SRV hostname to resolve:", srvHost);
  try {
    const srv = await dns.resolveSrv(srvHost);
    console.log("[DIAG] DNS SRV lookup OK. Records:", srv.length, srv);
  } catch (dnsErr) {
    console.error("[DIAG] DNS SRV lookup FAILED:", dnsErr.code || dnsErr.message);
    console.error("[DIAG] Full DNS error:", dnsErr);
  }
})();
// ----- END DIAGNOSTIC -----

const app = express();
app.use(cors());
app.use(express.json());

// Log all incoming requests
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Request body:', JSON.stringify(req.body, null, 2));
  }
  next();
});

// Setup routes BEFORE MongoDB connection (so they're always available)
const readingRoutes = require("./routes/readingRoutes");
const elderRoutes = require("./routes/elderRoutes");
const medicineRoutes = require("./routes/medicineRoutes");
const heartAlertRoutes = require("./routes/heartAlertRoutes");
app.use("/api/readings", readingRoutes);
app.use("/api/elders", elderRoutes);
app.use("/api/medicines", medicineRoutes);
app.use("/api/heart-alert", heartAlertRoutes);

// Connect to MongoDB, then start server
mongoose.connect(process.env.MONGO_URI, {
  serverSelectionTimeoutMS: 30000, // 30 seconds
  socketTimeoutMS: 45000, // 45 seconds
  connectTimeoutMS: 30000, // 30 seconds
  maxPoolSize: 10,
  retryWrites: true,
  w: 'majority'
})
  .then(() => {
    console.log("✅ MongoDB connected successfully");
    
    // Start server only after MongoDB is connected (0.0.0.0 = accept from any interface)
    const PORT = process.env.PORT || 5000;
    app.listen(PORT, '0.0.0.0', () => {
      console.log("✅ Server running on port " + PORT);
      console.log("✅ Ready to accept requests");
      console.log("✅ Routes registered:");
      console.log("   - GET/POST /api/readings");
      console.log("   - GET/POST /api/elders");
      console.log("   - GET/POST /api/medicines");
      console.log("   - GET/POST /api/heart-alert");
    });
  })
  .catch(err => {
    console.error("❌ MongoDB connection error:", err.message);
    console.error("Full error:", err);
    console.error("Server will not start without database connection");
    process.exit(1);
  });
