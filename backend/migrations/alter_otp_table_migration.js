const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    try {
        console.log('🚀 Updating otps table to use phone as foreign key...\n');

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

        // Helper function to check if constraint exists
        async function constraintExists(table, constraintName) {
            const [rows] = await connection.execute(
                `SELECT CONSTRAINT_NAME
                 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
                 WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = ?`,
                [process.env.DB_NAME || 'squad_db', table, constraintName]
            );
            return rows.length > 0;
        }

        // Helper function to check if column is nullable
        async function isColumnNullable(table, column) {
            const [rows] = await connection.execute(
                `SELECT IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
                [process.env.DB_NAME || 'squad_db', table, column]
            );
            return rows.length > 0 && rows[0].IS_NULLABLE === 'YES';
        }

        // Helper function to get column type
        async function getColumnType(table, column) {
            const [rows] = await connection.execute(
                `SELECT COLUMN_TYPE
                 FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
                [process.env.DB_NAME || 'squad_db', table, column]
            );
            return rows.length > 0 ? rows[0].COLUMN_TYPE : null;
        }

        // First, ensure phone is unique and not null in users table
        console.log('📋 Checking users table phone constraints...\n');

        // Check if there are any NULL phone values
        const [nullPhones] = await connection.execute('SELECT COUNT(*) as null_count FROM users WHERE phone IS NULL');
        const nullCount = nullPhones[0].null_count;

        if (nullCount > 0) {
            console.log(`⚠️  Found ${nullCount} users with NULL phone. Setting placeholder phones...\n`);
            // Get users with NULL phone and update them with unique placeholders
            const [nullUsers] = await connection.execute('SELECT id FROM users WHERE phone IS NULL ORDER BY id');
            for (let i = 0; i < nullUsers.length; i++) {
                const placeholder = `placeholder_${nullUsers[i].id}`;
                await connection.execute('UPDATE users SET phone = ? WHERE id = ?', [placeholder, nullUsers[i].id]);
            }
            console.log('✅ Set placeholder phones for users with NULL phone\n');
        }

        // Make phone NOT NULL if it's nullable
        if (await isColumnNullable('users', 'phone')) {
            await connection.execute('ALTER TABLE users MODIFY COLUMN phone VARCHAR(20) NOT NULL');
            console.log('✅ Made users.phone NOT NULL\n');
        }

        const [phoneIndex] = await connection.execute(
            `SELECT INDEX_NAME, NON_UNIQUE
             FROM INFORMATION_SCHEMA.STATISTICS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users' AND COLUMN_NAME = 'phone'`,
            [process.env.DB_NAME || 'squad_db']
        );

        if (phoneIndex.length === 0) {
            // No index on phone, add unique index
            await connection.execute('ALTER TABLE users ADD UNIQUE KEY uq_users_phone (phone)');
            console.log('✅ Added unique constraint on users.phone\n');
        } else if (phoneIndex[0].NON_UNIQUE === 1) {
            // Index exists but not unique, drop and recreate as unique
            await connection.execute('ALTER TABLE users DROP INDEX idx_phone, ADD UNIQUE KEY uq_users_phone (phone)');
            console.log('✅ Updated users.phone to unique constraint\n');
        } else {
            console.log('⏭️  users.phone is already unique\n');
        }

        // Check and align column types and collation
        const usersPhoneInfo = await connection.execute(
            `SELECT COLUMN_TYPE, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
            [process.env.DB_NAME || 'squad_db', 'users', 'phone']
        );
        const otpsPhoneInfo = await connection.execute(
            `SELECT COLUMN_TYPE, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
            [process.env.DB_NAME || 'squad_db', 'otps', 'phone']
        );

        const usersPhoneType = usersPhoneInfo[0][0].COLUMN_TYPE;
        const usersCollation = usersPhoneInfo[0][0].COLLATION_NAME;
        const otpsPhoneType = otpsPhoneInfo[0][0].COLUMN_TYPE;
        const otpsCollation = otpsPhoneInfo[0][0].COLLATION_NAME;

        console.log(`📋 users.phone type: ${usersPhoneType}, collation: ${usersCollation}`);
        console.log(`📋 otps.phone type: ${otpsPhoneType}, collation: ${otpsCollation}\n`);

        if (usersPhoneType !== otpsPhoneType || usersCollation !== otpsCollation) {
            // Make otps.phone match users.phone type and collation
            await connection.execute(`ALTER TABLE otps MODIFY COLUMN phone ${usersPhoneType} COLLATE ${usersCollation} NOT NULL`);
            console.log(`✅ Updated otps.phone to match users.phone: ${usersPhoneType} COLLATE ${usersCollation}\n`);
        }

        // Now handle otps table changes
        const hasEmail = await columnExists('otps', 'email');
        const hasPhone = await columnExists('otps', 'phone');

        if (hasEmail && !hasPhone) {
            // Rename email column to phone
            await connection.execute(`ALTER TABLE otps CHANGE COLUMN email phone ${usersPhoneType || 'VARCHAR(255)'} NOT NULL`);
            console.log('✅ Renamed email column to phone\n');

            // Update index name
            await connection.execute('ALTER TABLE otps DROP INDEX idx_email, ADD INDEX idx_phone (phone)');
            console.log('✅ Updated index from idx_email to idx_phone\n');
        } else if (!hasEmail && hasPhone) {
            console.log('⏭️  Table already uses phone column\n');
        } else if (!hasEmail && !hasPhone) {
            console.log('⚠️  Neither email nor phone column found. Please run the initial migration first.\n');
        } else {
            console.log('⚠️  Both email and phone columns exist. Manual intervention may be required.\n');
        }

        // Add foreign key constraint if it doesn't exist
        if (!(await constraintExists('otps', 'fk_otps_phone'))) {
            await connection.execute('ALTER TABLE otps ADD CONSTRAINT fk_otps_phone FOREIGN KEY (phone) REFERENCES users(phone) ON DELETE CASCADE');
            console.log('✅ Added foreign key constraint from otps.phone to users.phone\n');
        } else {
            console.log('⏭️  Foreign key constraint already exists\n');
        }

        console.log('🎉 Migration completed successfully!\n');
        await connection.end();

    } catch (error) {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    }
}

runMigration();