const db = require('../config/db');

exports.createNotification = async ({
  userId,
  actorId,
  type,
  postId = null
}) => {
  if (!userId || !actorId || !type) return;

  // Prevent self-notification
  if (userId === actorId) return;

  await db.query(
    `INSERT INTO notifications (user_id, actor_id, type, post_id)
     VALUES (?, ?, ?, ?)`,
    [userId, actorId, type, postId]
  );
};
