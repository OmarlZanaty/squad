const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    try {
        console.log('🚀 Adding pinned and archived columns to chats table...\n');

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

        // Add pinned_by_user1 column
        if (!(await columnExists('chats', 'pinned_by_user1'))) {
            await connection.execute('ALTER TABLE chats ADD COLUMN pinned_by_user1 BOOLEAN DEFAULT FALSE');
            console.log('✅ Added pinned_by_user1 column to chats table\n');
        } else {
            console.log('⏭️  pinned_by_user1 column already exists\n');
        }

        // Add pinned_by_user2 column
        if (!(await columnExists('chats', 'pinned_by_user2'))) {
            await connection.execute('ALTER TABLE chats ADD COLUMN pinned_by_user2 BOOLEAN DEFAULT FALSE');
            console.log('✅ Added pinned_by_user2 column to chats table\n');
        } else {
            console.log('⏭️  pinned_by_user2 column already exists\n');
        }

        // Add archived_by_user1 column
        if (!(await columnExists('chats', 'archived_by_user1'))) {
            await connection.execute('ALTER TABLE chats ADD COLUMN archived_by_user1 BOOLEAN DEFAULT FALSE');
            console.log('✅ Added archived_by_user1 column to chats table\n');
        } else {
            console.log('⏭️  archived_by_user1 column already exists\n');
        }

        // Add archived_by_user2 column
        if (!(await columnExists('chats', 'archived_by_user2'))) {
            await connection.execute('ALTER TABLE chats ADD COLUMN archived_by_user2 BOOLEAN DEFAULT FALSE');
            console.log('✅ Added archived_by_user2 column to chats table\n');
        } else {
            console.log('⏭️  archived_by_user2 column already exists\n');
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