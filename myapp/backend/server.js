const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const { createPool } = require("./db");
const { s3Client, bucketName } = require("./s3");
const photoRoutes = require("./routes/photos");
const userRoutes = require("./routes/users");

const app = express();
const PORT = process.env.PORT || 3000;

// --------------- Middleware ---------------
app.use(helmet());
app.use(morgan("combined"));
app.use(cors({
  origin: process.env.FRONTEND_URL || "*",
  methods: ["GET", "POST", "PUT", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"]
}));
app.use(express.json({ limit: "10mb" }));

// --------------- Health Check (ALB hits this) ---------------
app.get("/health", async (req, res) => {
  const checks = { status: "ok", timestamp: new Date().toISOString() };

  // Check DB connection
  try {
    const pool = createPool();
    const [rows] = await pool.execute("SELECT 1 AS alive");
    checks.database = "connected";
  } catch (err) {
    checks.database = "disconnected";
    checks.databaseError = err.message;
  }

  // Check S3 access
  try {
    if (bucketName) {
      const { HeadBucketCommand } = require("@aws-sdk/client-s3");
      await s3Client.send(new HeadBucketCommand({ Bucket: bucketName }));
      checks.s3 = "accessible";
    } else {
      checks.s3 = "not_configured";
    }
  } catch (err) {
    checks.s3 = "inaccessible";
    checks.s3Error = err.message;
  }

  const allHealthy = checks.database === "connected";
  res.status(allHealthy ? 200 : 503).json(checks);
});

// --------------- API Routes ---------------
app.use("/api/photos", photoRoutes);
app.use("/api/users", userRoutes);

// --------------- Root ---------------
app.get("/", (req, res) => {
  res.json({
    service: "myapp-backend",
    version: "1.0.0",
    endpoints: [
      "GET  /health",
      "GET  /api/users",
      "POST /api/users",
      "GET  /api/photos",
      "POST /api/photos/upload",
      "GET  /api/photos/:id/url"
    ]
  });
});

// --------------- 404 Handler ---------------
app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

// --------------- Error Handler ---------------
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ error: "Internal server error" });
});

// --------------- Start Server ---------------
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Backend running on port ${PORT}`);
  console.log(`DB_HOST: ${process.env.DB_HOST || "not set"}`);
  console.log(`S3_PHOTOS_BUCKET: ${process.env.S3_PHOTOS_BUCKET || "not set"}`);
});
