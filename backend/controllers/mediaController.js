const db = require('../db');
const imageProcessor = require('../utils/imageProcessor');
const videoProcessor = require('../utils/videoProcessor');
const fs = require('fs');
const path = require('path');

/**
 * Upload and process image
 * Compresses image and generates multiple sizes
 */
exports.uploadImage = async (req, res) => {
    const userId = req.user.id;

    try {
        if (!req.file) {
            return res.status(400).json({ message: "No image file provided." });
        }

        console.log('📸 Processing image upload from user:', userId);

        // Validate file type
        const allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (!allowedMimes.includes(req.file.mimetype)) {
            return res.status(400).json({ message: "Invalid image format. Allowed: JPEG, PNG, WebP, GIF" });
        }

        // Validate file size (max 50MB)
        const maxSize = 50 * 1024 * 1024;
        if (req.file.size > maxSize) {
            return res.status(400).json({ message: "Image file too large. Maximum: 50MB" });
        }

        // Process image
        const imageUrls = await imageProcessor.processAndUploadImage(
            req.file.buffer,
            req.file.originalname,
            `users/${userId}/images`
        );

        // Generate LQIP for progressive loading
        const lqip = await imageProcessor.generateLQIP(
            req.file.buffer,
            req.file.originalname
        );

        // Store image metadata in database
        const sql = `
            INSERT INTO post_media (
                user_id, 
                media_type, 
                original_url, 
                thumbnail_url, 
                medium_url, 
                large_url, 
                lqip_data, 
                original_size, 
                compressed_size,
                width,
                height,
                format
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

        const compressedSize = Math.round(
            (imageUrls.thumbnail ? 30 : 0) + 
            (imageUrls.medium ? 200 : 0) + 
            (imageUrls.large ? 500 : 0)
        ) * 1024; // Rough estimate in bytes

        const [result] = await db.query(sql, [
            userId,
            'image',
            imageUrls.original,
            imageUrls.thumbnail,
            imageUrls.medium,
            imageUrls.large,
            lqip,
            req.file.size,
            compressedSize,
            imageUrls.metadata.width,
            imageUrls.metadata.height,
            imageUrls.metadata.format
        ]);

        console.log('✅ Image metadata stored in database');

        res.status(201).json({
            message: "Image uploaded and processed successfully.",
            media_id: result.insertId,
            imageUrls: {
                original: imageUrls.original,
                thumbnail: imageUrls.thumbnail,
                medium: imageUrls.medium,
                large: imageUrls.large,
                lqip: lqip
            },
            metadata: imageUrls.metadata,
            compression: {
                originalSize: `${(req.file.size / 1024 / 1024).toFixed(2)}MB`,
                compressedSize: `${(compressedSize / 1024 / 1024).toFixed(2)}MB`,
                ratio: `${((1 - compressedSize / req.file.size) * 100).toFixed(2)}%`
            }
        });

    } catch (error) {
        console.error("Image upload error:", error);
        res.status(500).json({ message: `Image upload failed: ${error.message}` });
    }
};

/**
 * Upload and process video
 * Compresses video to multiple quality levels
 */
exports.uploadVideo = async (req, res) => {
    const userId = req.user.id;

    try {
        if (!req.file) {
            return res.status(400).json({ message: "No video file provided." });
        }

        console.log('🎥 Processing video upload from user:', userId);

        // Validate file type
        const allowedMimes = ['video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm'];
        if (!allowedMimes.includes(req.file.mimetype)) {
            return res.status(400).json({ message: "Invalid video format. Allowed: MP4, MOV, AVI, WebM" });
        }

        // Validate file size (max 500MB)
        const maxSize = 500 * 1024 * 1024;
        if (req.file.size > maxSize) {
            return res.status(400).json({ message: "Video file too large. Maximum: 500MB" });
        }

        // Save temp file for processing
        const tempDir = path.join('/tmp', `squad-video-${Date.now()}`);
        if (!fs.existsSync(tempDir)) {
            fs.mkdirSync(tempDir, { recursive: true });
        }

        const tempFilePath = path.join(tempDir, req.file.originalname);
        fs.writeFileSync(tempFilePath, req.file.buffer);

        console.log('📝 Temp file saved:', tempFilePath);

        // Process video
        const videoUrls = await videoProcessor.processAndUploadVideo(
            tempFilePath,
            req.file.originalname,
            `users/${userId}/videos`
        );

        // Store video metadata in database
        const sql = `
            INSERT INTO post_media (
                user_id,
                media_type,
                thumbnail_url,
                low_quality_url,
                medium_quality_url,
                high_quality_url,
                original_size,
                compressed_size,
                duration,
                codec,
                width,
                height,
                format
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;

        const totalCompressedSize = Object.values(videoUrls.qualities).reduce((sum, q) => sum + q.size, 0);

        const [result] = await db.query(sql, [
            userId,
            'video',
            videoUrls.thumbnail,
            videoUrls.qualities.low?.url,
            videoUrls.qualities.medium?.url,
            videoUrls.qualities.high?.url,
            req.file.size,
            totalCompressedSize,
            videoUrls.metadata.originalDuration,
            videoUrls.metadata.originalCodec,
            videoUrls.metadata.originalResolution.split('x')[0],
            videoUrls.metadata.originalResolution.split('x')[1],
            'mp4'
        ]);

        console.log('✅ Video metadata stored in database');

        // Clean up temp file
        fs.unlinkSync(tempFilePath);
        fs.rmdirSync(tempDir);

        res.status(201).json({
            message: "Video uploaded and processed successfully.",
            media_id: result.insertId,
            videoUrls: {
                thumbnail: videoUrls.thumbnail,
                low: videoUrls.qualities.low,
                medium: videoUrls.qualities.medium,
                high: videoUrls.qualities.high
            },
            metadata: videoUrls.metadata,
            compression: {
                originalSize: `${(req.file.size / 1024 / 1024).toFixed(2)}MB`,
                compressedSize: `${(totalCompressedSize / 1024 / 1024).toFixed(2)}MB`,
                ratio: `${((1 - totalCompressedSize / req.file.size) * 100).toFixed(2)}%`
            }
        });

    } catch (error) {
        console.error("Video upload error:", error);
        res.status(500).json({ message: `Video upload failed: ${error.message}` });
    }
};

/**
 * Get media metadata
 */
exports.getMediaMetadata = async (req, res) => {
    const { mediaId } = req.params;

    try {
        const [media] = await db.query(
            "SELECT * FROM post_media WHERE id = ?",
            [mediaId]
        );

        if (media.length === 0) {
            return res.status(404).json({ message: "Media not found." });
        }

        res.status(200).json(media[0]);

    } catch (error) {
        console.error("Get media metadata error:", error);
        res.status(500).json({ message: "Server error while fetching media metadata." });
    }
};

/**
 * Get user's media library
 */
exports.getUserMediaLibrary = async (req, res) => {
    const userId = req.user.id;
    const { mediaType, page = 1, limit = 20 } = req.query;

    try {
        const offset = (page - 1) * limit;
        let sql = "SELECT * FROM post_media WHERE user_id = ?";
        const params = [userId];

        if (mediaType) {
            sql += " AND media_type = ?";
            params.push(mediaType);
        }

        sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?";
        params.push(parseInt(limit), offset);

        const [media] = await db.query(sql, params);

        // Get total count
        let countSql = "SELECT COUNT(*) as total FROM post_media WHERE user_id = ?";
        const countParams = [userId];

        if (mediaType) {
            countSql += " AND media_type = ?";
            countParams.push(mediaType);
        }

        const [countResult] = await db.query(countSql, countParams);
        const total = countResult[0].total;

        res.status(200).json({
            media,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                pages: Math.ceil(total / limit)
            }
        });

    } catch (error) {
        console.error("Get user media library error:", error);
        res.status(500).json({ message: "Server error while fetching media library." });
    }
};

/**
 * Delete media
 */
exports.deleteMedia = async (req, res) => {
    const userId = req.user.id;
    const { mediaId } = req.params;

    try {
        // Verify ownership
        const [media] = await db.query(
            "SELECT * FROM post_media WHERE id = ? AND user_id = ?",
            [mediaId, userId]
        );

        if (media.length === 0) {
            return res.status(404).json({ message: "Media not found or you don't have permission." });
        }

        // Delete from database
        await db.query(
            "DELETE FROM post_media WHERE id = ?",
            [mediaId]
        );

        // TODO: delete local file from storage/uploads

        res.status(200).json({ message: "Media deleted successfully." });

    } catch (error) {
        console.error("Delete media error:", error);
        res.status(500).json({ message: "Server error while deleting media." });
    }
};

/**
 * Get image compression preview
 * Shows what compression will look like
 */
exports.previewImageCompression = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: "No image file provided." });
        }

        // Extract metadata without uploading
        const metadata = await imageProcessor.extractImageMetadata(req.file.buffer);
        const lqip = await imageProcessor.generateLQIP(req.file.buffer, req.file.originalname);

        res.status(200).json({
            message: "Image compression preview",
            original: {
                size: `${(req.file.size / 1024 / 1024).toFixed(2)}MB`,
                ...metadata
            },
            preview: {
                lqip: lqip,
                estimatedCompression: {
                    thumbnail: `~${(metadata.size * 0.05 / 1024).toFixed(2)}KB`,
                    medium: `~${(metadata.size * 0.15 / 1024).toFixed(2)}KB`,
                    large: `~${(metadata.size * 0.25 / 1024).toFixed(2)}KB`,
                    totalSaved: `~${((1 - 0.45) * 100).toFixed(2)}%`
                }
            }
        });

    } catch (error) {
        console.error("Preview compression error:", error);
        res.status(500).json({ message: `Preview failed: ${error.message}` });
    }
};
