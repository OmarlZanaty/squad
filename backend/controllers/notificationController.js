const db = require('../db');

// Get all notifications for the current user
exports.getNotifications = async (req, res) => {
    const userId = req.user.id;
    const page = parseInt(req.query.page, 10) || 1;
    const limit = 20;
    const offset = (page - 1) * limit;

    try {
        const sql = `
            SELECT 
                n.id, n.type, n.is_read, n.created_at,
                n.actor_id, u.name as actor_name, u.profile_photo_url as actor_photo,
                n.post_id, p.caption as post_caption, p.media_url as post_media, p.media_type as post_media_type
            FROM notifications n
            JOIN users u ON n.actor_id = u.id
            LEFT JOIN posts p ON n.post_id = p.id
            WHERE n.user_id = ?
            ORDER BY n.created_at DESC
            LIMIT ? OFFSET ?
        `;

        const [notifications] = await db.query(sql, [userId, limit, offset]);

        // Get unread count
        const [countResult] = await db.query(
            "SELECT COUNT(*) as unread_count FROM notifications WHERE user_id = ? AND is_read = 0", 
            [userId]
        );

        res.status(200).json({
            success: true,
            notifications,
            unread_count: countResult[0].unread_count
        });
    } catch (error) {
        console.error("Get Notifications Error:", error);
        res.status(500).json({ message: 'Server error while fetching notifications.' });
    }
};

// Get ONLY unread count (for polling/badges)
exports.getUnreadCount = async (req, res) => {
    const userId = req.user.id;
    try {
        const [rows] = await db.query(
            'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0',
            [userId]
        );
        res.json({ success: true, count: rows[0].count });
    } catch (error) {
        console.error('Error getting unread notification count:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
};

// Mark a single notification as read
exports.markAsRead = async (req, res) => {
    const userId = req.user.id;
    const { id } = req.params;

    try {
        await db.query(
            "UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?", 
            [id, userId]
        );
        res.status(200).json({ success: true });
    } catch (error) {
        console.error("Mark Read Error:", error);
        res.status(500).json({ message: 'Server error.' });
    }
};

// Mark all notifications as read
exports.markAllRead = async (req, res) => {
    const userId = req.user.id;

    try {
        await db.query(
            "UPDATE notifications SET is_read = 1 WHERE user_id = ?", 
            [userId]
        );
        res.status(200).json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
        console.error("Mark All Read Error:", error);
        res.status(500).json({ message: 'Server error.' });
    }
};

// Delete a notification
exports.deleteNotification = async (req, res) => {
    const userId = req.user.id;
    const { id } = req.params;

    try {
        await db.query(
            "DELETE FROM notifications WHERE id = ? AND user_id = ?", 
            [id, userId]
        );
        res.status(200).json({ success: true });
    } catch (error) {
        console.error("Delete Notification Error:", error);
        res.status(500).json({ message: 'Server error.' });
    }
};

// Internal helper to create a notification (to be used by other controllers)
exports.createNotification = async (userId, actorId, type, postId = null) => {
    if (userId === actorId) return; // Don't notify users about their own actions

    try {
        // Check for duplicate notification (e.g., multiple likes on same post)
        if (type === 'like' || type === 'love' || type === 'talent' || type === 'amazing') {
            const [existing] = await db.query(
                "SELECT id FROM notifications WHERE user_id = ? AND actor_id = ? AND type = ? AND post_id = ?",
                [userId, actorId, type, postId]
            );
            
            if (existing.length > 0) {
                // Update timestamp instead of creating new one
                await db.query(
                    "UPDATE notifications SET created_at = NOW(), is_read = 0 WHERE id = ?",
                    [existing[0].id]
                );
                return;
            }
        }

        await db.query(
            "INSERT INTO notifications (user_id, actor_id, type, post_id) VALUES (?, ?, ?, ?)",
            [userId, actorId, type, postId]
        );
    } catch (error) {
        console.error("Create Notification Error:", error);
        // Don't throw, just log - notifications shouldn't break main flow
    }
};