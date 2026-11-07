const { createPool } = require("./db");

async function runMigrations() {
  console.log("Running database migrations...");

  const pool = createPool();

  const migrations = [
    {
      name: "create_users_table",
      sql: `
        CREATE TABLE IF NOT EXISTS users (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) NOT NULL UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX idx_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `
    },
    {
      name: "create_photos_table",
      sql: `
        CREATE TABLE IF NOT EXISTS photos (
          id INT AUTO_INCREMENT PRIMARY KEY,
          user_id INT NOT NULL,
          filename VARCHAR(500) NOT NULL,
          s3_key VARCHAR(1000) NOT NULL,
          content_type VARCHAR(100) NOT NULL,
          size_bytes INT NOT NULL DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_user_id (user_id),
          INDEX idx_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      `
    }
  ];

  for (const migration of migrations) {
    try {
      await pool.execute(migration.sql);
      console.log(`  OK: ${migration.name}`);
    } catch (err) {
      console.error(`  FAILED: ${migration.name}`, err.message);
      process.exit(1);
    }
  }

  console.log("All migrations complete.");
  await pool.end();
  process.exit(0);
}

runMigrations();
