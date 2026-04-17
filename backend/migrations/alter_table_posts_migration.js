const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    try {
        console.log('🚀 Adding media columns to posts table...\n');

        const connection = await mysql.createConnection({
            host: process.env.DB_HOST || 'localhost',
            user: process.env.DB_USER || 'squad_user',
            password: process.env.DB_PASSWORD,
            database: process.env.DB_NAME || 'squad_db'
        });

        console.log('✅ Connected to database\n');

        // Helper function to check if column exists
        async function columnExists(table, column) {
            const [rows] = await connection.execute(
                `SELECT COLUMN_NAME 
                 FROM INFORMATION_SCHEMA.COLUMNS 
                 WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
                [process.env.DB_NAME || 'squad_db', table, column]
            );
            return rows.length > 0;
        }

        // Add media_count column
        if (!(await columnExists('posts', 'media_count'))) {
            await connection.execute('ALTER TABLE posts ADD COLUMN media_count INT DEFAULT 0');
            console.log('✅ Added media_count column\n');
        } else {
            console.log('⏭️  media_count column already exists\n');
        }

        // Add is_collage column
        if (!(await columnExists('posts', 'is_collage'))) {
            await connection.execute('ALTER TABLE posts ADD COLUMN is_collage BOOLEAN DEFAULT FALSE');
            console.log('✅ Added is_collage column\n');
        } else {
            console.log('⏭️  is_collage column already exists\n');
        }

        // Add collage_layout column
        if (!(await columnExists('posts', 'collage_layout'))) {
            await connection.execute('ALTER TABLE posts ADD COLUMN collage_layout VARCHAR(50)');
            console.log('✅ Added collage_layout column\n');
        } else {
            console.log('⏭️  collage_layout column already exists\n');
        }

        console.log('\n✨ Migration completed successfully!');

        await connection.end();
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        process.exit(1);
    }
}

runMigration();