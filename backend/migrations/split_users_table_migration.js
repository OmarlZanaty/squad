const mysql = require('mysql2/promise');
require('dotenv').config();

async function splitUsersTable() {
    let connection;
    try {
        console.log('🚀 Starting users table split migration...\n');

        // Connect to database
        connection = await mysql.createConnection({
            host: process.env.DB_HOST || 'localhost',
            user: process.env.DB_USER || 'squad_user',
            password: process.env.DB_PASSWORD,
            database: process.env.DB_NAME || 'squad_db'
        });

        console.log('✅ Connected to database\n');

        // Start transaction
        await connection.query('START TRANSACTION');

        // Disable foreign key checks
        await connection.query('SET FOREIGN_KEY_CHECKS = 0');

        // Drop existing tables if they exist
        await connection.query('DROP TABLE IF EXISTS old_users');
        await connection.query('DROP TABLE IF EXISTS players');
        await connection.query('DROP TABLE IF EXISTS scouts');
        await connection.query('DROP TABLE IF EXISTS guests');
        await connection.query('DROP TABLE IF EXISTS admins');
        await connection.query('DROP TABLE IF EXISTS new_users');

        // 1. Create new users table (base table)
        await connection.query(`
            CREATE TABLE new_users (
                id INT PRIMARY KEY AUTO_INCREMENT,
                name VARCHAR(255) NOT NULL,
                password VARCHAR(255) NOT NULL,
                type ENUM('player','scout','guest','admin') NOT NULL,
                status ENUM('pending','active') NOT NULL DEFAULT 'pending',
                profile_photo_url TEXT DEFAULT NULL,
                cover_photo_url TEXT DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        `);

        // 2. Create players table
        await connection.query(`
            CREATE TABLE players (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                email VARCHAR(255) DEFAULT NULL,
                phone VARCHAR(20) DEFAULT NULL,
                country VARCHAR(100) DEFAULT NULL,
                position VARCHAR(100) DEFAULT NULL,
                bio TEXT DEFAULT NULL,
                current_club VARCHAR(255) DEFAULT NULL,
                weight INT DEFAULT NULL COMMENT 'Player weight in kg',
                height INT DEFAULT NULL COMMENT 'Player height in cm',
                age INT DEFAULT NULL COMMENT 'Player age',
                full_name VARCHAR(255) DEFAULT NULL,
                national_id VARCHAR(50) DEFAULT NULL COMMENT 'Player national ID number',
                birth_date DATE DEFAULT NULL COMMENT 'Player birth date',
                rating DECIMAL(3,2) DEFAULT 0.00,
                FOREIGN KEY (user_id) REFERENCES new_users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_email (email),
                INDEX idx_rating (rating),
                INDEX idx_age (age)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        `);

        // 3. Create scouts table
        await connection.query(`
            CREATE TABLE scouts (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                email VARCHAR(255) DEFAULT NULL,
                phone VARCHAR(20) DEFAULT NULL,
                FOREIGN KEY (user_id) REFERENCES new_users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_email (email)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        `);

        // 4. Create guests table
        await connection.query(`
            CREATE TABLE guests (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                email VARCHAR(255) DEFAULT NULL,
                phone VARCHAR(20) DEFAULT NULL,
                FOREIGN KEY (user_id) REFERENCES new_users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_email (email)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        `);

        // 5. Create admins table
        await connection.query(`
            CREATE TABLE admins (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                email VARCHAR(255) DEFAULT NULL,
                phone VARCHAR(20) DEFAULT NULL,
                FOREIGN KEY (user_id) REFERENCES new_users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_email (email)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        `);

        // 6. Migrate data from old users table
        console.log('📦 Migrating data...\n');

        // Get all users
        const [users] = await connection.execute('SELECT * FROM users');

        for (const user of users) {
            // Insert into new_users
            const userData = [
                user.id,
                user.name || null,
                user.password || null,
                user.type || null,
                user.status || null,
                user.profile_photo_url || null,
                user.cover_photo_url || null,
                user.created_at || null
            ];
            const [result] = await connection.execute(`
                INSERT INTO new_users (id, name, password, type, status, profile_photo_url, cover_photo_url, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            `, userData);

            const newUserId = result.insertId;

            // Insert into role-specific table
            if (user.type === 'player') {
                const playerData = [
                    newUserId,
                    user.email || null,
                    user.phone || null,
                    user.country || null,
                    user.position || null,
                    user.bio || null,
                    user.current_club || null,
                    user.weight || null,
                    user.height || null,
                    user.age || null,
                    user.full_name || null,
                    user.national_id || null,
                    user.birth_date || null,
                    user.rating || 0.00
                ];
                await connection.execute(`
                    INSERT INTO players (user_id, email, phone, country, position, bio, current_club, weight, height, age, full_name, national_id, birth_date, rating)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `, playerData);
            } else if (user.type === 'scout') {
                await connection.execute(`
                    INSERT INTO scouts (user_id, email, phone)
                    VALUES (?, ?, ?)
                `, [newUserId, user.email || null, user.phone || null]);
            } else if (user.type === 'guest') {
                await connection.execute(`
                    INSERT INTO guests (user_id, email, phone)
                    VALUES (?, ?, ?)
                `, [newUserId, user.email || null, user.phone || null]);
            } else if (user.type === 'admin') {
                await connection.execute(`
                    INSERT INTO admins (user_id, email, phone)
                    VALUES (?, ?, ?)
                `, [newUserId, user.email || null, user.phone || null]);
            }
        }

        // 7. Drop foreign keys that reference users
        const fkConstraints = [
            'career_history_ibfk_1',
            'chats_ibfk_1',
            'chats_ibfk_2',
            'comments_ibfk_2',
            'follows_ibfk_1',
            'follows_ibfk_2',
            'messages_ibfk_2',
            'notifications_ibfk_1',
            'posts_ibfk_1',
            'reactions_ibfk_2'
        ];

        for (const constraint of fkConstraints) {
            try {
                await connection.query(`ALTER TABLE ${constraint.split('_ibfk_')[0]} DROP FOREIGN KEY ${constraint}`);
            } catch (e) {
                // Constraint might not exist
            }
        }

        // Also drop otps foreign key on phone
        try {
            await connection.query('ALTER TABLE otps DROP FOREIGN KEY fk_otps_phone');
        } catch (e) {}

        // Rename tables
        await connection.query('RENAME TABLE users TO old_users');
        await connection.query('RENAME TABLE new_users TO users');

        // Add back the foreign keys to the new users table
        await connection.query('ALTER TABLE career_history ADD CONSTRAINT career_history_ibfk_1 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE chats ADD CONSTRAINT chats_ibfk_1 FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE chats ADD CONSTRAINT chats_ibfk_2 FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE comments ADD CONSTRAINT comments_ibfk_2 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE follows ADD CONSTRAINT follows_ibfk_1 FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE follows ADD CONSTRAINT follows_ibfk_2 FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE messages ADD CONSTRAINT messages_ibfk_2 FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE notifications ADD CONSTRAINT notifications_ibfk_1 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE posts ADD CONSTRAINT posts_ibfk_1 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE');
        await connection.query('ALTER TABLE reactions ADD CONSTRAINT reactions_ibfk_2 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE');

        // For media tables, add back if they exist
        const mediaTables = ['post_media', 'upload_queue', 'upload_chunks', 'post_analytics', 'video_watch_events', 'storage_usage', 'shareable_links', 'post_shares'];
        for (const table of mediaTables) {
            try {
                await connection.query(`ALTER TABLE ${table} ADD CONSTRAINT fk_${table}_user_id FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`);
            } catch (e) {}
        }

        // For otps, since phone is not in users anymore, we need to handle differently. Perhaps drop the fk for now.
        // await connection.query('ALTER TABLE otps ADD CONSTRAINT fk_otps_phone FOREIGN KEY (phone) REFERENCES users(phone) ON DELETE CASCADE'); // Can't do this

        // 8. Drop old users table
        await connection.query('DROP TABLE old_users');

        // Commit transaction
        await connection.query('SET FOREIGN_KEY_CHECKS = 1');
        await connection.query('COMMIT');

        console.log('✅ Users table split migration completed successfully!\n');

    } catch (error) {
        console.error('❌ Migration failed:', error);
        if (connection) {
            await connection.query('SET FOREIGN_KEY_CHECKS = 1');
            await connection.query('ROLLBACK');
        }
        throw error;
    } finally {
        if (connection) {
            await connection.end();
        }
    }
}

// Run the migration
if (require.main === module) {
    splitUsersTable().catch(console.error);
}

module.exports = splitUsersTable;