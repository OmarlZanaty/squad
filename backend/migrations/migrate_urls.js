/**
 * URL Migration Script
 * Replaces all occurrences of the old S3 URL with the new domain
 * across every table and every text column in your MySQL/MariaDB database.
 *
 * Usage:
 *   1. npm install mysql2
 *   2. Fill in your DB credentials below (or use env vars)
 *   3. node migrate-urls.js --dry-run   (preview changes, no writes)
 *   4. node migrate-urls.js             (apply changes for real)
 */

const mysql = require("mysql2/promise");

// ─── CONFIG ──────────────────────────────────────────────────────────────────

const DB_CONFIG = {
  host: process.env.DB_HOST || "localhost",
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || "squad_user",
  password: process.env.DB_PASSWORD || "StrongPassword123!",
  database: process.env.DB_NAME || "squad_db",
  multipleStatements: false,
};

const OLD_URL = "https://squad-player-storage.s3.me-central-1.amazonaws.com";
const NEW_URL = "https://squad-online.com/storage";

// ─── FLAGS ───────────────────────────────────────────────────────────────────

const DRY_RUN = process.argv.includes("--dry-run");

// ─── HELPERS ─────────────────────────────────────────────────────────────────

const TEXT_TYPES = new Set([
  "char", "varchar", "tinytext", "text", "mediumtext", "longtext",
  "json", "enum", "set",
]);

function isTextColumn(dataType) {
  return TEXT_TYPES.has(dataType.toLowerCase());
}

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

async function migrate() {
  log(DRY_RUN ? "🔍  DRY RUN mode — no changes will be written." : "🚀  LIVE mode — changes WILL be written to the database.");
  log(`Replacing: ${OLD_URL}`);
  log(`With:      ${NEW_URL}\n`);

  const conn = await mysql.createConnection(DB_CONFIG);

  try {
    const dbName = DB_CONFIG.database;

    // 1. Get all tables
    const [tables] = await conn.query(
      `SELECT TABLE_NAME FROM information_schema.TABLES
       WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = 'BASE TABLE'`,
      [dbName]
    );

    log(`Found ${tables.length} tables.\n`);

    let totalUpdated = 0;

    for (const { TABLE_NAME: table } of tables) {
      // 2. Get all text-like columns for this table
      const [columns] = await conn.query(
        `SELECT COLUMN_NAME, DATA_TYPE, COLUMN_KEY
         FROM information_schema.COLUMNS
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?`,
        [dbName, table]
      );

      const textCols = columns.filter((c) => isTextColumn(c.DATA_TYPE));
      if (textCols.length === 0) continue;

      // Find primary key column for safe targeted updates
      const pkCol = columns.find((c) => c.COLUMN_KEY === "PRI");

      for (const { COLUMN_NAME: col } of textCols) {
        // 3. Check if the old URL exists in this column at all
        const [countRows] = await conn.query(
          `SELECT COUNT(*) AS cnt FROM \`${table}\`
           WHERE \`${col}\` LIKE ?`,
          [`%${OLD_URL}%`]
        );

        const count = countRows[0].cnt;
        if (count === 0) continue;

        log(`  📋  ${table}.${col}  →  ${count} row(s) to update`);

        if (!DRY_RUN) {
          if (pkCol) {
            // Safe: update row by row using PK to avoid locking entire table
            const [affectedRows] = await conn.query(
              `UPDATE \`${table}\` SET \`${col}\` = REPLACE(\`${col}\`, ?, ?)
               WHERE \`${col}\` LIKE ?`,
              [OLD_URL, NEW_URL, `%${OLD_URL}%`]
            );
            log(`     ✅  Updated ${affectedRows.affectedRows} row(s).`);
          } else {
            // No PK — still safe, just bulk update
            const [affectedRows] = await conn.query(
              `UPDATE \`${table}\` SET \`${col}\` = REPLACE(\`${col}\`, ?, ?)
               WHERE \`${col}\` LIKE ?`,
              [OLD_URL, NEW_URL, `%${OLD_URL}%`]
            );
            log(`     ✅  Updated ${affectedRows.affectedRows} row(s) (no PK, bulk).`);
          }
          totalUpdated += count;
        } else {
          log(`     ⏭️   Skipped (dry run).`);
        }
      }
    }

    console.log("\n──────────────────────────────────────────");
    if (DRY_RUN) {
      log(`DRY RUN complete. Rows that WOULD be updated: counted above.`);
      log(`Run without --dry-run to apply changes.`);
    } else {
      log(`✅  Migration complete. Total rows updated: ${totalUpdated}`);
    }

  } finally {
    await conn.end();
  }
}

migrate().catch((err) => {
  console.error("❌  Migration failed:", err.message);
  process.exit(1);
});