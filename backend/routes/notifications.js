const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const { authenticateToken } = require('../middleware/authMiddleware'); // Destructure to get the function

// All routes require authentication
router.use(authenticateToken);

router.get('/unread-count', notificationController.getUnreadCount);
router.get('/', notificationController.getNotifications);
router.put('/read-all', notificationController.markAllRead);
router.put('/:id/read', notificationController.markAsRead);
router.delete('/:id', notificationController.deleteNotification);

module.exports = router;