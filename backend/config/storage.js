const multer = require('multer');
const path = require('path');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowedImageTypes = /jpeg|jpg|png|gif|webp/;

  // ✅ allow ALL common video extensions (including MPEG-2 uploads)
  const allowedVideoTypes = /mp4|mov|avi|mkv|webm|m4v|mpg|mpeg|ts|m2ts|mts|3gp|flv|wmv|asf/;

  const extname = path.extname(file.originalname).toLowerCase();
  const extension = extname.substring(1);

  const isImage = allowedImageTypes.test(extension);
  const isVideo = allowedVideoTypes.test(extension);

  if (isImage || isVideo) {
    return cb(null, true);
  } else {
    return cb(new Error('Only image/video files are allowed!'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB
  },
});

module.exports = upload;
