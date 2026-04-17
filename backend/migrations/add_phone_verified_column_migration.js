const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    try {
        console.log('🚀 Adding phone_verified column to users table...\n');

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

        // Add phone_verified column
        if (!(await columnExists('users', 'phone_verified'))) {
            await connection.execute('ALTER TABLE users ADD COLUMN phone_verified BOOLEAN DEFAULT FALSE');
            console.log('✅ Added phone_verified column to users table\n');
        } else {
            console.log('⏭️  phone_verified column already exists\n');
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