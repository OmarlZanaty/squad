const express = require("express");
const router = express.Router();
const profileController = require("../controllers/profileController");
const { authenticateToken } = require("../middleware/authMiddleware");

router.post('/:id/share', authenticateToken, profileController.shareProfile);

module.exports = router;