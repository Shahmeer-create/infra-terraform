const express = require("express");
const router = express.Router();
const { createPool } = require("../db");

// GET /api/users — list all users
router.get("/", async (req, res) => {
  try {
    const pool = createPool();
    const [rows] = await pool.execute(
      "SELECT id, name, email, created_at FROM users ORDER BY created_at DESC LIMIT 100"
    );
    res.json({ users: rows });
  } catch (err) {
    console.error("Error fetching users:", err);
    res.status(500).json({ error: "Failed to fetch users" });
  }
});

// GET /api/users/:id — get one user
router.get("/:id", async (req, res) => {
  try {
    const pool = createPool();
    const [rows] = await pool.execute(
      "SELECT id, name, email, created_at FROM users WHERE id = ?",
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    res.json({ user: rows[0] });
  } catch (err) {
    console.error("Error fetching user:", err);
    res.status(500).json({ error: "Failed to fetch user" });
  }
});

// POST /api/users — create a user
router.post("/", async (req, res) => {
  try {
    const { name, email } = req.body;
    if (!name || !email) {
      return res.status(400).json({ error: "name and email are required" });
    }
    const pool = createPool();
    const [result] = await pool.execute(
      "INSERT INTO users (name, email) VALUES (?, ?)",
      [name, email]
    );
    res.status(201).json({
      user: { id: result.insertId, name, email }
    });
  } catch (err) {
    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ error: "Email already exists" });
    }
    console.error("Error creating user:", err);
    res.status(500).json({ error: "Failed to create user" });
  }
});

// DELETE /api/users/:id — delete a user
router.delete("/:id", async (req, res) => {
  try {
    const pool = createPool();
    const [result] = await pool.execute(
      "DELETE FROM users WHERE id = ?",
      [req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    res.json({ message: "User deleted" });
  } catch (err) {
    console.error("Error deleting user:", err);
    res.status(500).json({ error: "Failed to delete user" });
  }
});

module.exports = router;
