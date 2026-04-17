// Admin Routes for Squad Backend
// Add these routes to your Express server

const express = require('express');
const router = express.Router();

// Admin Authentication Middleware
const adminAuth = (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  // Verify admin token (implement your own verification)
  // For now, checking if user type is 'admin'
  const jwt = require('jsonwebtoken');
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
    if (decoded.type !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }
    req.admin = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

// ==================== DASHBOARD STATS ====================

router.get('/stats', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db'); // Assuming db is attached to app
    
    // Get total users
    const [usersCount] = await db.query('SELECT COUNT(*) as count FROM users');
    
    // Get pending users (if you have approval system)
    const [pendingCount] = await db.query(
      "SELECT COUNT(*) as count FROM users WHERE status = 'pending'"
    );
    
    // Get total posts
    const [postsCount] = await db.query('SELECT COUNT(*) as count FROM posts');
    
    // Get total chats
    const [chatsCount] = await db.query('SELECT COUNT(*) as count FROM chats');
    
    res.json({
      success: true,
      stats: {
        totalUsers: usersCount[0].count,
        pendingUsers: pendingCount[0].count,
        totalPosts: postsCount[0].count,
        totalChats: chatsCount[0].count
      }
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ==================== USER MANAGEMENT ====================

// Get all users
router.get('/users', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { search, type, status, page = 1, limit = 50 } = req.query;
    
    let query = 'SELECT u.*, p.country, p.position, p.bio, p.current_club, p.weight, p.height, p.age, p.full_name, p.national_id, p.birth_date, p.rating FROM users u LEFT JOIN players p ON u.id = p.user_id WHERE 1=1';
    const params = [];
    
    if (search) {
      query += ' AND (name LIKE ? OR email LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }
    
    if (type) {
      query += ' AND type = ?';
      params.push(type);
    }
    
    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }
    
    query += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), (parseInt(page) - 1) * parseInt(limit));
    
    const [users] = await db.query(query, params);
    
    // Get total count
    let countQuery = 'SELECT COUNT(*) as count FROM users WHERE 1=1';
    const countParams = [];
    
    if (search) {
      countQuery += ' AND (name LIKE ? OR email LIKE ?)';
      countParams.push(`%${search}%`, `%${search}%`);
    }
    
    if (type) {
      countQuery += ' AND type = ?';
      countParams.push(type);
    }
    
    if (status) {
      countQuery += ' AND status = ?';
      countParams.push(status);
    }
    
    const [countResult] = await db.query(countQuery, countParams);
    
    res.json({
      success: true,
      users: users,
      total: countResult[0].count,
      page: parseInt(page),
      limit: parseInt(limit)
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Create user
router.post('/users', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { name, email, password, type, country, position } = req.body;
    
    // Hash password
    const bcrypt = require('bcrypt');
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const [result] = await db.query(
      'INSERT INTO users (name, email, password, type, status) VALUES (?, ?, ?, ?, ?)',
      [name, email, hashedPassword, type, 'active']
    );
    
    const userId = result.insertId;
    
    // Insert into role-specific table
    if (type === 'player') {
      await db.query(
        'INSERT INTO players (user_id, country, position) VALUES (?, ?, ?)',
        [userId, country || null, position || null]
      );
    }
    
    res.json({
      success: true,
      message: 'User created successfully',
      userId: userId
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Update user
router.put('/users/:id', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    const { name, email, type, status, country, position } = req.body;
    
    await db.query(
      'UPDATE users SET name = ?, email = ?, type = ?, status = ? WHERE id = ?',
      [name, email, type, status, id]
    );
    
    // Update role-specific table
    if (type === 'player') {
      await db.query(
        'UPDATE players SET country = ?, position = ? WHERE user_id = ?',
        [country, position, id]
      );
    }
    
    res.json({
      success: true,
      message: 'User updated successfully'
    });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete user
router.delete('/users/:id', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    await db.query('DELETE FROM users WHERE id = ?', [id]);
    
    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ==================== APPROVAL MANAGEMENT ====================

// Get pending approvals
router.get('/approvals', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    
    const [pending] = await db.query(
      "SELECT u.*, p.country, p.position FROM users u LEFT JOIN players p ON u.id = p.user_id WHERE u.status = 'pending' ORDER BY u.created_at DESC"
    );
    
    res.json({
      success: true,
      approvals: pending
    });
  } catch (error) {
    console.error('Error fetching approvals:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Approve user
router.post('/approvals/:id/approve', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    await db.query("UPDATE users SET status = 'active' WHERE id = ?", [id]);
    
    res.json({
      success: true,
      message: 'User approved successfully'
    });
  } catch (error) {
    console.error('Error approving user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Reject user
router.post('/approvals/:id/reject', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    await db.query("UPDATE users SET status = 'rejected' WHERE id = ?", [id]);
    
    res.json({
      success: true,
      message: 'User rejected successfully'
    });
  } catch (error) {
    console.error('Error rejecting user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Approve all pending
router.post('/approvals/approve-all', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    
    await db.query("UPDATE users SET status = 'active' WHERE status = 'pending'");
    
    res.json({
      success: true,
      message: 'All pending users approved'
    });
  } catch (error) {
    console.error('Error approving all:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ==================== POST MANAGEMENT ====================

// Get all posts
router.get('/posts', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { search, page = 1, limit = 50 } = req.query;
    
    let query = `
      SELECT p.*, u.name as user_name, u.profile_photo_url
      FROM posts p
      JOIN users u ON p.user_id = u.id
      WHERE 1=1
    `;
    const params = [];
    
    if (search) {
      query += ' AND p.content LIKE ?';
      params.push(`%${search}%`);
    }
    
    query += ' ORDER BY p.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(limit), (parseInt(page) - 1) * parseInt(limit));
    
    const [posts] = await db.query(query, params);
    
    res.json({
      success: true,
      posts: posts
    });
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete post
router.delete('/posts/:id', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    await db.query('DELETE FROM posts WHERE id = ?', [id]);
    
    res.json({
      success: true,
      message: 'Post deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting post:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete all posts
router.delete('/posts', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    
    await db.query('DELETE FROM posts');
    
    res.json({
      success: true,
      message: 'All posts deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting all posts:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ==================== CHAT MANAGEMENT ====================

// Get all chats
router.get('/chats', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    
    const [chats] = await db.query(`
      SELECT c.*, 
        u1.name as user1_name, u1.profile_photo_url as user1_photo,
        u2.name as user2_name, u2.profile_photo_url as user2_photo
      FROM chats c
      JOIN users u1 ON c.user_id_1 = u1.id
      JOIN users u2 ON c.user_id_2 = u2.id
      ORDER BY c.created_at DESC
    `);
    
    res.json({
      success: true,
      chats: chats
    });
  } catch (error) {
    console.error('Error fetching chats:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get messages for a chat
router.get('/chats/:id/messages', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    const [messages] = await db.query(`
      SELECT m.*, u.name as sender_name, u.profile_photo_url as sender_photo
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.chat_id = ?
      ORDER BY m.created_at ASC
    `, [id]);
    
    res.json({
      success: true,
      messages: messages
    });
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Delete chat
router.delete('/chats/:id', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    const { id } = req.params;
    
    // Delete messages first
    await db.query('DELETE FROM messages WHERE chat_id = ?', [id]);
    // Delete chat
    await db.query('DELETE FROM chats WHERE id = ?', [id]);
    
    res.json({
      success: true,
      message: 'Chat deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting chat:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ==================== EXPORT FUNCTIONS ====================

// Export users to CSV
router.get('/export/users', adminAuth, async (req, res) => {
  try {
    const db = req.app.get('db');
    
    const [users] = await db.query('SELECT u.*, p.country, p.position, p.bio, p.current_club, p.weight, p.height, p.age, p.full_name, p.national_id, p.birth_date, p.rating FROM users u LEFT JOIN players p ON u.id = p.user_id');
    
    // Convert to CSV
    const csv = convertToCSV(users);
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=users.csv');
    res.send(csv);
  } catch (error) {
    console.error('Error exporting users:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Helper function to convert to CSV
function convertToCSV(data) {
  if (data.length === 0) return '';
  
  const headers = Object.keys(data[0]).join(',');
  const rows = data.map(row => 
    Object.values(row).map(value => 
      typeof value === 'string' ? `"${value}"` : value
    ).join(',')
  );
  
  return [headers, ...rows].join('\n');
}

module.exports = router;
