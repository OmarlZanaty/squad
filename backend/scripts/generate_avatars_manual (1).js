const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
const https = require('https');

// ============================================
// MANUAL CONFIGURATION - UPDATE THESE VALUES
// ============================================
const DB_CONFIG = {
  host: 'localhost',      // Your database host (e.g., 'localhost', '127.0.0.1', or remote IP)
  user: 'squad_user',           // Your database username
  password: 'StrongPassword123!',           // Your database password
  database: 'squad_db'    // Your database name
};

// Avatar configuration
const AVATAR_CONFIG = {
  size: 200,
  background: 'random',
  color: 'ffffff',
  bold: true,
  rounded: false
};

// ============================================
// FUNCTIONS
// ============================================

/**
 * Generate initials from a name
 */
function generateInitials(name) {
  if (!name || typeof name !== 'string') return 'U';
  
  const parts = name.trim().split(/\s+/);
  
  if (parts.length === 1) {
    return parts[0].substring(0, 2).toUpperCase();
  }
  
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

/**
 * Download avatar from UI Avatars API
 */
function downloadAvatar(name, filepath) {
  return new Promise((resolve, reject) => {
    const initials = generateInitials(name);
    const url = `https://ui-avatars.com/api/?name=${encodeURIComponent(initials)}&size=${AVATAR_CONFIG.size}&background=${AVATAR_CONFIG.background}&color=${AVATAR_CONFIG.color}&bold=${AVATAR_CONFIG.bold}&rounded=${AVATAR_CONFIG.rounded}`;
    
    const file = fs.createWriteStream(filepath);
    
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download avatar: ${response.statusCode}`));
        return;
      }
      
      response.pipe(file);
      
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(filepath, () => {}); // Delete the file if error
      reject(err);
    });
  });
}

/**
 * Main function to generate avatars
 */
async function generateAllAvatars() {
  let connection;
  
  try {
    console.log('🚀 Starting avatar generation...\n');
    
    // Create database connection
    console.log('📡 Connecting to database...');
    connection = await mysql.createConnection(DB_CONFIG);
    console.log('✅ Connected to database\n');
    
    // Ensure avatars directory exists
    const avatarsDir = path.join(__dirname, '..', 'public', 'avatars');
    if (!fs.existsSync(avatarsDir)) {
      fs.mkdirSync(avatarsDir, { recursive: true });
      console.log('📁 Created avatars directory\n');
    }
    
    // Fetch all users without profile photos
    console.log('🔍 Fetching users without profile photos...');
    const [users] = await connection.execute(
      'SELECT id, name, profile_photo FROM users WHERE profile_photo IS NULL OR profile_photo = ""'
    );
    
    console.log(`📊 Found ${users.length} users without profile photos\n`);
    
    if (users.length === 0) {
      console.log('✨ All users already have profile photos!');
      return;
    }
    
    // Generate avatars for each user
    let successCount = 0;
    let failCount = 0;
    
    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      const progress = `[${i + 1}/${users.length}]`;
      
      try {
        console.log(`${progress} Processing: ${user.name} (ID: ${user.id})`);
        
        // Generate filename
        const filename = `user_${user.id}.png`;
        const filepath = path.join(avatarsDir, filename);
        const dbPath = `/avatars/${filename}`;
        
        // Download avatar
        await downloadAvatar(user.name, filepath);
        
        // Update database
        await connection.execute(
          'UPDATE users SET profile_photo = ? WHERE id = ?',
          [dbPath, user.id]
        );
        
        console.log(`   ✅ Generated: ${filename}\n`);
        successCount++;
        
      } catch (error) {
        console.log(`   ❌ Failed: ${error.message}\n`);
        failCount++;
      }
    }
    
    // Summary
    console.log('═══════════════════════════════════════');
    console.log('📈 SUMMARY');
    console.log('═══════════════════════════════════════');
    console.log(`✅ Successful: ${successCount}`);
    console.log(`❌ Failed: ${failCount}`);
    console.log(`📊 Total: ${users.length}`);
    console.log('═══════════════════════════════════════\n');
    
    if (successCount > 0) {
      console.log('🎉 Avatar generation completed!');
      console.log(`📁 Avatars saved to: ${avatarsDir}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
    console.error('\n💡 Make sure to update the DB_CONFIG values at the top of this script!');
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Database connection closed');
    }
  }
}

// ============================================
// RUN SCRIPT
// ============================================

console.log('═══════════════════════════════════════');
console.log('🎨 SQUAD AVATAR GENERATOR');
console.log('═══════════════════════════════════════');
console.log('Database Config:');
console.log(`  Host: ${DB_CONFIG.host}`);
console.log(`  User: ${DB_CONFIG.user}`);
console.log(`  Database: ${DB_CONFIG.database}`);
console.log('═══════════════════════════════════════\n');

generateAllAvatars();
