const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure upload directories exist
const profileUploadDir = 'uploads/profiles';
const coverUploadDir = 'uploads/covers';
fs.mkdirSync(profileUploadDir, { recursive: true });
fs.mkdirSync(coverUploadDir, { recursive: true });

// Configure multer for profile and cover photo uploads
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        if (file.fieldname === 'profile_photo') {
            cb(null, profileUploadDir);
        } else if (file.fieldname === 'cover_photo') {
            cb(null, coverUploadDir);
        } else {
            cb(new Error('Invalid field name'));
        }
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const fileFilter = (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = path.extname(file.originalname).toLowerCase();
    const extension = extname.substring(1);
    
    if (allowedTypes.test(extension)) {
        cb(null, true);
    } else {
        cb(new Error('Only image files (jpeg, jpg, png, gif, webp) are allowed!'));
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit for profile images
    }
});

// Auth routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/profile', authenticateToken, authController.getProfile);

// Profile update route with image uploads
router.put('/update-profile', 
    authenticateToken, 
    upload.fields([
        { name: 'profile_photo', maxCount: 1 },
        { name: 'cover_photo', maxCount: 1 }
    ]), 
    authController.updateProfile
);

module.exports = router;
