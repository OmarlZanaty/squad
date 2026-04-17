const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { authenticateToken } = require('../middleware/authMiddleware');

// DELETE /api/messages/:id (soft delete message)
router.delete('/:id', authenticateToken, chatController.deleteMessage);

// PUT /api/messages/:id (edit message)
router.put('/:id', authenticateToken, chatController.editMessage);

// POST /api/messages/:id/pin (pin/unpin message)
router.post('/:id/pin', authenticateToken, chatController.pinMessage);

module.exports = router;