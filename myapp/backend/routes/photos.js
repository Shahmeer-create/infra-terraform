const express = require("express");
const multer = require("multer");
const crypto = require("crypto");
const path = require("path");
const { PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { s3Client, bucketName } = require("../s3");
const { createPool } = require("../db");

const router = express.Router();

// Multer stores file in memory temporarily before uploading to S3
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
  fileFilter: (req, file, cb) => {
    const allowed = [".jpg", ".jpeg", ".png", ".gif", ".webp"];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error("Only image files are allowed (jpg, png, gif, webp)"));
    }
  }
});

// GET /api/photos — list all photos
router.get("/", async (req, res) => {
  try {
    const pool = createPool();
    const [rows] = await pool.execute(
      "SELECT id, user_id, filename, s3_key, content_type, size_bytes, created_at FROM photos ORDER BY created_at DESC LIMIT 100"
    );
    res.json({ photos: rows });
  } catch (err) {
    console.error("Error fetching photos:", err);
    res.status(500).json({ error: "Failed to fetch photos" });
  }
});

// POST /api/photos/upload — upload a photo to S3 and save metadata in DB
router.post("/upload", upload.single("photo"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No photo file provided" });
    }
    if (!bucketName) {
      return res.status(503).json({ error: "S3 bucket not configured" });
    }

    const userId = req.body.user_id;
    if (!userId) {
      return res.status(400).json({ error: "user_id is required" });
    }

    // Generate unique S3 key
    const uniqueId = crypto.randomUUID();
    const ext = path.extname(req.file.originalname).toLowerCase();
    const s3Key = `photos/${userId}/${uniqueId}${ext}`;

    // Upload to S3
    await s3Client.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: s3Key,
      Body: req.file.buffer,
      ContentType: req.file.mimetype
    }));

    // Save metadata in DB
    const pool = createPool();
    const [result] = await pool.execute(
      "INSERT INTO photos (user_id, filename, s3_key, content_type, size_bytes) VALUES (?, ?, ?, ?, ?)",
      [userId, req.file.originalname, s3Key, req.file.mimetype, req.file.size]
    );

    res.status(201).json({
      photo: {
        id: result.insertId,
        user_id: userId,
        filename: req.file.originalname,
        s3_key: s3Key,
        size_bytes: req.file.size
      }
    });
  } catch (err) {
    console.error("Error uploading photo:", err);
    res.status(500).json({ error: "Failed to upload photo" });
  }
});

// GET /api/photos/:id/url — get a presigned URL to view the photo
router.get("/:id/url", async (req, res) => {
  try {
    const pool = createPool();
    const [rows] = await pool.execute(
      "SELECT s3_key FROM photos WHERE id = ?",
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "Photo not found" });
    }
    if (!bucketName) {
      return res.status(503).json({ error: "S3 bucket not configured" });
    }

    // Generate presigned URL (valid for 1 hour)
    const url = await getSignedUrl(
      s3Client,
      new GetObjectCommand({ Bucket: bucketName, Key: rows[0].s3_key }),
      { expiresIn: 3600 }
    );

    res.json({ url });
  } catch (err) {
    console.error("Error generating presigned URL:", err);
    res.status(500).json({ error: "Failed to generate URL" });
  }
});

// DELETE /api/photos/:id — delete photo from S3 and DB
router.delete("/:id", async (req, res) => {
  try {
    const pool = createPool();
    const [rows] = await pool.execute(
      "SELECT s3_key FROM photos WHERE id = ?",
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "Photo not found" });
    }

    // Delete from S3
    if (bucketName) {
      await s3Client.send(new DeleteObjectCommand({
        Bucket: bucketName,
        Key: rows[0].s3_key
      }));
    }

    // Delete from DB
    await pool.execute("DELETE FROM photos WHERE id = ?", [req.params.id]);

    res.json({ message: "Photo deleted" });
  } catch (err) {
    console.error("Error deleting photo:", err);
    res.status(500).json({ error: "Failed to delete photo" });
  }
});

module.exports = router;
