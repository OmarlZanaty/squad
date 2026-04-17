const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure the upload directory exists
const uploadDir = 'uploads/posts/media';
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadDir); // Save files to the 'uploads/posts/media' directory
    },
    filename: function (req, file, cb) {
        // Create a unique filename: fieldname-timestamp.extension
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
});

// File filter to accept images and videos
const fileFilter = (req, file, cb) => {
    const allowedImageTypes = /jpeg|jpg|png|gif|webp/;
    const allowedVideoTypes = /mp4|mov|avi|mkv|webm|m4v/;
    
    const extname = path.extname(file.originalname).toLowerCase();
    const extension = extname.substring(1); // Remove the dot
    const isImage = allowedImageTypes.test(extension);
    const isVideo = allowedVideoTypes.test(extension);
    
    if (isImage || isVideo) {
        cb(null, true);
    } else {
        cb(new Error('Only image files (jpeg, jpg, png, gif, webp) and video files (mp4, mov, avi, mkv, webm, m4v) are allowed!'));
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 100 * 1024 * 1024 // 100MB limit for videos
    }
});

module.exports = upload;