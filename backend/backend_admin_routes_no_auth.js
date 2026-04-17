// Admin Dashboard API Routes (No Authentication)
const express = require('express');
const router = express.Router();

// Get database from app
let db;
router.use((req, res, next) => {
  db = req.app.get('db');
  next();
});

// ============================================
// STATISTICS ENDPOINT
// ============================================
router.get('/stats', async (req, res) => {
  try {
    // Get total users
    const [usersResult] = await db.query('SELECT COUNT(*) as count FROM users');
    const totalUsers = usersResult[0].count;

    // Get pending approvals
    const [pendingResult] = await db.query(
      "SELECT COUNT(*) as count FROM users WHERE status = 'pending'"
    );
    const pendingApprovals = pendingResult[0].count;

    // Get total posts
    const [postsResult] = await db.query('SELECT COUNT(*) as count FROM posts');
    const totalPosts = postsResult[0].count;

    // Get total chats
    const [chatsResult] = await db.query('SELECT COUNT(*) as count FROM chats');
    const totalChats = chatsResult[0].count;

    res.json({
      totalUsers,
      pendingApprovals,
      totalPosts,
      totalChats
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// USERS ENDPOINTS
// ============================================

// Get all users
router.get('/users', async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT 
        u.id, 
        u.name, 
        u.email, 
        CASE 
          WHEN u.type = 'player' THEN p.position 
          ELSE NULL 
        END as position,
        u.status,
        u.created_at
      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.phone_verified = 1
      ORDER BY u.created_at DESC
    `);
    
    res.json({ users });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single user details
router.get('/users/:id', async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT 
        u.id,
        u.name,
        u.email,
        CASE 
          WHEN u.type = 'player' THEN p.position 
          ELSE NULL 
        END as position,
        CASE 
          WHEN u.type = 'player' THEN p.bio 
          ELSE NULL 
        END as bio,
        u.profile_photo_url as profile_image,
        u.status,
        u.created_at,
        (SELECT COUNT(*) FROM posts WHERE user_id = u.id) as posts_count,
        (SELECT COUNT(*) FROM chats WHERE user1_id = u.id OR user2_id = u.id) as chats_count
      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.id = ?
    `, [req.params.id]);
    
    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ user: users[0] });
  } catch (error) {
    console.error('Error fetching user details:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update user
router.put('/users/:id', async (req, res) => {
  try {
    const { name, email, position, status } = req.body;
    
    // Update basic user info
    await db.query(
      'UPDATE users SET name = ?, email = ?, status = ? WHERE id = ?',
      [name, email, status, req.params.id]
    );
    
    // If position is provided and user is a player, update player table
    if (position !== undefined) {
      // Check if user is a player
      const [userCheck] = await db.query('SELECT type FROM users WHERE id = ?', [req.params.id]);
      if (userCheck.length > 0 && userCheck[0].type === 'player') {
        await db.query(
          'UPDATE players SET position = ? WHERE user_id = ?',
          [position, req.params.id]
        );
      }
    }
    
    res.json({ success: true, message: 'User updated successfully' });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete user
router.delete('/users/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// APPROVALS ENDPOINTS
// ============================================

// Get pending approvals
router.get('/approvals', async (req, res) => {
  try {
    const [users] = await db.query(`
      SELECT 
        id, 
        name, 
        email, 
        position,
        created_at
      FROM users
      WHERE status = 'pending'
      ORDER BY created_at DESC
    `);
    
    res.json({ users });
  } catch (error) {
    console.error('Error fetching approvals:', error);
    res.status(500).json({ error: error.message });
  }
});

// Approve user
router.post('/approvals/:id/approve', async (req, res) => {
  try {
    await db.query("UPDATE users SET status = 'active' WHERE id = ?", [req.params.id]);
    res.json({ success: true, message: 'User approved successfully' });
  } catch (error) {
    console.error('Error approving user:', error);
    res.status(500).json({ error: error.message });
  }
});

// Reject user
router.post('/approvals/:id/reject', async (req, res) => {
  try {
    await db.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json({ success: true, message: 'User rejected and deleted' });
  } catch (error) {
    console.error('Error rejecting user:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// POSTS ENDPOINTS
// ============================================

// Get all posts
router.get('/posts', async (req, res) => {
  try {
    const [posts] = await db.query(`
      SELECT 
        p.id,
        p.user_id,
        p.caption,
        p.media_type,
        p.media_url,
        p.created_at,
        u.name as author_name,
        (SELECT COUNT(*) FROM reactions WHERE post_id = p.id) as likes_count,
        0 as comments_count
      FROM posts p
      LEFT JOIN users u ON p.user_id = u.id
      ORDER BY p.created_at DESC
    `);
    
    res.json({ posts });
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update post
router.put('/posts/:id', async (req, res) => {
  try {
    const { caption } = req.body;
    
    const [result] = await db.query(
      'UPDATE posts SET caption = ? WHERE id = ?',
      [caption, req.params.id]
    );
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    
    res.json({ success: true, message: 'Post updated successfully' });
  } catch (error) {
    console.error('Error updating post:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete post
router.delete('/posts/:id', async (req, res) => {
  try {
    // Delete related data first
    await db.query('DELETE FROM reactions WHERE post_id = ?', [req.params.id]);
    await db.query('DELETE FROM posts WHERE id = ?', [req.params.id]);
    
    res.json({ success: true, message: 'Post deleted successfully' });
  } catch (error) {
    console.error('Error deleting post:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// CHATS ENDPOINTS
// ============================================

// Get all chats
router.get('/chats', async (req, res) => {
  try {
    const [chats] = await db.query(`
      SELECT 
        c.id,
        c.user1_id,
        c.user2_id,
        c.created_at,
        u1.name as user1_name,
        u2.name as user2_name,
        (
          SELECT message 
          FROM messages 
          WHERE chat_id = c.id 
          ORDER BY created_at DESC 
          LIMIT 1
        ) as last_message
      FROM chats c
      LEFT JOIN users u1 ON c.user1_id = u1.id
      LEFT JOIN users u2 ON c.user2_id = u2.id
      ORDER BY c.created_at DESC
    `);
    
    res.json({ chats });
  } catch (error) {
    console.error('Error fetching chats:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete chat
router.delete('/chats/:id', async (req, res) => {
  try {
    // Delete messages first, then chat
    await db.query('DELETE FROM messages WHERE chat_id = ?', [req.params.id]);
    await db.query('DELETE FROM chats WHERE id = ?', [req.params.id]);
    
    res.json({ success: true, message: 'Chat deleted successfully' });
  } catch (error) {
    console.error('Error deleting chat:', error);
    res.status(500).json({ error: error.message });
  }
});

// ============================================
// NOTIFICATIONS ENDPOINT
// ============================================

router.post('/notifications/send', async (req, res) => {
  try {
    const { type, title, message, userId } = req.body;
    
    // This is a placeholder - implement your actual notification sending logic
    // Could use Firebase Cloud Messaging, OneSignal, etc.
    
    console.log('Notification sent:', { type, title, message, userId });
    
    res.json({ success: true, message: 'Notification sent successfully' });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

module.exports = router;