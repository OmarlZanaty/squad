const express = require('express');
const router = express.Router();
const multer = require('multer');
const mediaController = require('../controllers/mediaController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Configure multer for in-memory file storage
const storage = multer.memoryStorage();

const imageUpload = multer({
    storage: storage,
    limits: { fileSize: 50 * 1024 * 1024 }, // 50MB
    fileFilter: (req, file, cb) => {
        const allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (allowedMimes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid image format'));
        }
    }
});

const videoUpload = multer({
    storage: storage,
    limits: { fileSize: 500 * 1024 * 1024 }, // 500MB
    fileFilter: (req, file, cb) => {
        const allowedMimes = ['video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm'];
        if (allowedMimes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(new Error('Invalid video format'));
        }
    }
});

/**
 * Upload and process image
 * POST /api/media/upload-image
 */
router.post('/upload-image', authenticateToken, imageUpload.single('image'), mediaController.uploadImage);

/**
 * Upload and process video
 * POST /api/media/upload-video
 */
router.post('/upload-video', authenticateToken, videoUpload.single('video'), mediaController.uploadVideo);

/**
 * Preview image compression (without uploading)
 * POST /api/media/preview-compression
 */
router.post('/preview-compression', authenticateToken, imageUpload.single('image'), mediaController.previewImageCompression);

/**
 * Get user's media library
 * GET /api/media/library
 * MUST come BEFORE /:mediaId route to avoid being matched as a parameter
 */
router.get('/library', authenticateToken, mediaController.getUserMediaLibrary);

/**
 * Get media metadata
 * GET /api/media/:mediaId
 */
router.get('/:mediaId', authenticateToken, mediaController.getMediaMetadata);

/**
 * Delete media
 * DELETE /api/media/:mediaId
 */
router.delete('/:mediaId', authenticateToken, mediaController.deleteMedia);

module.exports = router;
