const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { authenticateToken } = require('../middleware/authMiddleware');

// POST /api/chats/start
router.post('/start', authenticateToken, chatController.startChat);

// POST /api/chats/:id/send
router.post('/:id/send', authenticateToken, chatController.sendMessage);

// GET /api/chats/:id/messages
router.get('/:id/messages', authenticateToken, chatController.getMessages);

// GET /api/chats (list all chats for the user)
router.get('/', authenticateToken, chatController.getChatList);

router.delete('/:id', authenticateToken, chatController.deleteChat);

router.patch('/:id/pin', authenticateToken, chatController.pinChat);
router.patch('/:id/archive', authenticateToken, chatController.archiveChat);

router.patch('/messages/:id/pin', authenticateToken, chatController.pinMessage);
// Block / Unblock the other user in this chat
router.post('/:id/block', authenticateToken, chatController.blockUser);
router.delete('/:id/block', authenticateToken, chatController.unblockUser);

// Report the other user in this chat
router.post('/:id/report', authenticateToken, chatController.reportUser);

module.exports = router;
