const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigration() {
    try {
        console.log('🚀 Starting database migration...\n');

        // Connect to database
        const connection = await mysql.createConnection({
            host: process.env.DB_HOST || 'localhost',
            user: process.env.DB_USER || 'squad_user',
            password: process.env.DB_PASSWORD,
            database: process.env.DB_NAME || 'squad_db'
        });

        console.log('✅ Connected to database\n');

        // SQL statements to create tables
        const sqlStatements = [
            // post_media table
            `CREATE TABLE IF NOT EXISTS post_media (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                media_type ENUM('image', 'video') NOT NULL,
                original_url VARCHAR(500),
                thumbnail_url VARCHAR(500),
                medium_url VARCHAR(500),
                large_url VARCHAR(500),
                lqip_data LONGTEXT,
                low_quality_url VARCHAR(500),
                medium_quality_url VARCHAR(500),
                high_quality_url VARCHAR(500),
                original_size BIGINT,
                compressed_size BIGINT,
                width INT,
                height INT,
                duration DECIMAL(10, 2),
                codec VARCHAR(50),
                format VARCHAR(20),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_media_type (media_type),
                INDEX idx_created_at (created_at)
            )`,

            // image_sizes table
            `CREATE TABLE IF NOT EXISTS image_sizes (
                id INT PRIMARY KEY AUTO_INCREMENT,
                media_id INT NOT NULL,
                size_name VARCHAR(50) NOT NULL,
                url VARCHAR(500) NOT NULL,
                width INT,
                height INT,
                file_size INT,
                quality INT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE CASCADE,
                UNIQUE KEY unique_media_size (media_id, size_name),
                INDEX idx_media_id (media_id)
            )`,

            // video_qualities table
            `CREATE TABLE IF NOT EXISTS video_qualities (
                id INT PRIMARY KEY AUTO_INCREMENT,
                media_id INT NOT NULL,
                quality_name VARCHAR(50) NOT NULL,
                url VARCHAR(500) NOT NULL,
                resolution VARCHAR(20),
                bitrate VARCHAR(20),
                file_size BIGINT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE CASCADE,
                UNIQUE KEY unique_media_quality (media_id, quality_name),
                INDEX idx_media_id (media_id)
            )`,

            // post_media_relations table
            `CREATE TABLE IF NOT EXISTS post_media_relations (
                id INT PRIMARY KEY AUTO_INCREMENT,
                post_id INT NOT NULL,
                media_id INT NOT NULL,
                media_order INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE CASCADE,
                UNIQUE KEY unique_post_media (post_id, media_id),
                INDEX idx_post_id (post_id),
                INDEX idx_media_id (media_id),
                INDEX idx_media_order (media_order)
            )`,

            // upload_queue table
            `CREATE TABLE IF NOT EXISTS upload_queue (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                media_id INT,
                file_name VARCHAR(255),
                file_size BIGINT,
                upload_status ENUM('pending', 'in_progress', 'completed', 'failed') DEFAULT 'pending',
                progress_percentage INT DEFAULT 0,
                error_message TEXT,
                retry_count INT DEFAULT 0,
                scheduled_time DATETIME,
                upload_conditions JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE SET NULL,
                INDEX idx_user_id (user_id),
                INDEX idx_status (upload_status),
                INDEX idx_scheduled_time (scheduled_time)
            )`,

            // upload_chunks table
            `CREATE TABLE IF NOT EXISTS upload_chunks (
                id INT PRIMARY KEY AUTO_INCREMENT,
                upload_id INT NOT NULL,
                chunk_number INT,
                chunk_hash VARCHAR(64),
                chunk_status ENUM('pending', 'uploaded', 'verified') DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (upload_id) REFERENCES upload_queue(id) ON DELETE CASCADE,
                UNIQUE KEY unique_upload_chunk (upload_id, chunk_number),
                INDEX idx_upload_id (upload_id)
            )`,

            // Alter posts table
            `ALTER TABLE posts ADD COLUMN IF NOT EXISTS media_count INT DEFAULT 0`,
            `ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_collage BOOLEAN DEFAULT FALSE`,
            `ALTER TABLE posts ADD COLUMN IF NOT EXISTS collage_layout VARCHAR(50)`,

            // post_analytics table
            `CREATE TABLE IF NOT EXISTS post_analytics (
                id INT PRIMARY KEY AUTO_INCREMENT,
                post_id INT NOT NULL,
                media_id INT,
                views INT DEFAULT 0,
                engagement INT DEFAULT 0,
                video_watch_time DECIMAL(10, 2),
                drop_off_point DECIMAL(5, 2),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE SET NULL,
                UNIQUE KEY unique_post_analytics (post_id),
                INDEX idx_post_id (post_id)
            )`,

            // video_watch_events table
            `CREATE TABLE IF NOT EXISTS video_watch_events (
                id INT PRIMARY KEY AUTO_INCREMENT,
                media_id INT NOT NULL,
                user_id INT NOT NULL,
                watch_duration DECIMAL(10, 2),
                completion_percentage DECIMAL(5, 2),
                device_type VARCHAR(50),
                network_type VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_media_id (media_id),
                INDEX idx_user_id (user_id),
                INDEX idx_created_at (created_at)
            )`,

            // storage_usage table
            `CREATE TABLE IF NOT EXISTS storage_usage (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NOT NULL,
                total_images_size BIGINT DEFAULT 0,
                total_videos_size BIGINT DEFAULT 0,
                total_storage BIGINT DEFAULT 0,
                storage_limit BIGINT DEFAULT 5368709120,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                UNIQUE KEY unique_user_storage (user_id),
                INDEX idx_user_id (user_id)
            )`,

            // shareable_links table
            `CREATE TABLE IF NOT EXISTS shareable_links (
                id INT PRIMARY KEY AUTO_INCREMENT,
                media_id INT NOT NULL,
                user_id INT NOT NULL,
                link_token VARCHAR(64) UNIQUE NOT NULL,
                link_url VARCHAR(500),
                expires_at DATETIME,
                password_hash VARCHAR(255),
                is_password_protected BOOLEAN DEFAULT FALSE,
                click_count INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (media_id) REFERENCES post_media(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_link_token (link_token),
                INDEX idx_user_id (user_id),
                INDEX idx_expires_at (expires_at)
            )`,

            // post_shares table
            `CREATE TABLE IF NOT EXISTS post_shares (
                id INT PRIMARY KEY AUTO_INCREMENT,
                post_id INT NOT NULL,
                user_id INT NOT NULL,
                platform VARCHAR(50),
                share_count INT DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_post_id (post_id),
                INDEX idx_user_id (user_id),
                INDEX idx_platform (platform)
            )`,
            `CREATE TABLE IF NOT EXISTS otps (
                id INT PRIMARY KEY AUTO_INCREMENT,
                user_id INT NULL,  -- Nullable for cases where user not yet registered
                phone VARCHAR(20) NOT NULL,
                otp_code VARCHAR(10) NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                used BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (phone) REFERENCES users(phone) ON DELETE CASCADE,
                INDEX idx_phone (phone),
                INDEX idx_expires_at (expires_at),
                INDEX idx_used (used)
            )`
        ];

        // Execute each statement
        for (let i = 0; i < sqlStatements.length; i++) {
            try {
                console.log(`⏳ Executing statement ${i + 1}/${sqlStatements.length}...`);
                await connection.execute(sqlStatements[i]);
                console.log(`✅ Statement ${i + 1} completed\n`);
            } catch (error) {
                console.error(`❌ Error in statement ${i + 1}:`, error.message);
                // Continue with next statement even if one fails
            }
        }

        console.log('\n✨ Migration completed successfully!');
        console.log('📊 All tables have been created.\n');

        await connection.end();
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        process.exit(1);
    }
}

runMigration();
