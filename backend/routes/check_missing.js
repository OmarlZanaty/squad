const mysql = require('mysql2/promise');
const fs = require('fs');

const BASE_URL = 'http://187.124.37.68:3000/storage';
const STORAGE_PATH = '/var/www/squad_backend/storage';

(async () => {

const db = await mysql.createConnection({
  host: 'localhost',
  user: 'app_user',
  password: 'StrongPassword123',
  database: 'squad_db'
});

  const [rows] = await db.execute(`
    SELECT profile_photo_url AS url FROM users WHERE profile_photo_url IS NOT NULL
    UNION
    SELECT cover_photo_url FROM users WHERE cover_photo_url IS NOT NULL
    UNION
    SELECT media_url FROM posts WHERE media_url IS NOT NULL
  `);

  console.log(`🔍 Checking ${rows.length} files...\n`);

  let missing = [];
  let s3 = [];

  for (let row of rows) {
    if (!row.url) continue;

    // ⚠️ detect old S3 links
    if (row.url.includes('amazonaws')) {
      console.log("⚠️ S3 URL (not migrated):", row.url);
      s3.push(row.url);
      continue;
    }

    // convert URL → file path
    let filePath = row.url.replace(BASE_URL, STORAGE_PATH);

    if (!fs.existsSync(filePath)) {
      console.log("❌ Missing:", row.url);
      missing.push(row.url);
    }
  }

  fs.writeFileSync('missing_files.txt', missing.join('\n'));
  fs.writeFileSync('s3_files.txt', s3.join('\n'));

  console.log(`\n✅ Done`);
  console.log(`❌ Missing files: ${missing.length}`);
  console.log(`⚠️ S3 files: ${s3.length}`);
})();