const { createNotification } = require('../services/notificationService');

await createNotification({
  userId: targetUserId,
  senderId: req.user.id,
  type: 'follow',
  referenceId: null,
  message: `${req.user.name} started following you`,
});
