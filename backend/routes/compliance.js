const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticateToken } = require('../middleware/authMiddleware');
const db = require('../db');


// ============ REPORT CONTENT ============

router.get('/delete-account', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'delete-account.html'));
});

// Create a report
router.post('/reports', authenticateToken, async (req, res) => {
  try {
    const { content_id, content_type, reason, details } = req.body;
    const reporter_id = req.user.id;

    // Validate content_type
    const validTypes = ['post', 'comment', 'user'];
    if (!validTypes.includes(content_type)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid content type. Must be post, comment, or user.'
      });
    }

    // Check if already reported
    const [existing] = await db.query(
      'SELECT id FROM reports WHERE reporter_id = ? AND content_id = ? AND content_type = ? AND status = "pending"',
      [reporter_id, content_id, content_type]
    );

    if (existing.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'You have already reported this content.'
      });
    }

    // Create report
    const [result] = await db.query(
      `INSERT INTO reports (reporter_id, content_id, content_type, reason, details, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'pending', NOW())`,
      [reporter_id, content_id, content_type, reason, details || '']
    );

    res.status(201).json({
      success: true,
      message: 'Report submitted successfully.',
      data: { id: result.insertId }
    });
  } catch (error) {
    console.error('Error creating report:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get reports (admin only)
router.get('/reports', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const [user] = await db.query('SELECT type FROM users WHERE id = ?', [req.user.id]);
    if (!user.length || user[0].type !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const { status = 'pending', page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const [reports] = await db.query(
      `SELECT r.*, u.name as reporter_name, u.email as reporter_email
       FROM reports r
       JOIN users u ON r.reporter_id = u.id
       WHERE r.status = ?
       ORDER BY r.created_at DESC
       LIMIT ? OFFSET ?`,
      [status, parseInt(limit), parseInt(offset)]
    );

    res.json({ success: true, data: reports });
  } catch (error) {
    console.error('Error fetching reports:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Update report status (admin only)
router.put('/reports/:id', authenticateToken, async (req, res) => {
  try {
    // Check if user is admin
    const [user] = await db.query('SELECT type FROM users WHERE id = ?', [req.user.id]);
    if (!user.length || user[0].type !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const { status, admin_notes } = req.body;
    const validStatuses = ['pending', 'reviewed', 'resolved', 'dismissed'];
    
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    await db.query(
      'UPDATE reports SET status = ?, admin_notes = ?, reviewed_at = NOW(), reviewed_by = ? WHERE id = ?',
      [status, admin_notes || '', req.user.id, req.params.id]
    );

    res.json({ success: true, message: 'Report updated successfully' });
  } catch (error) {
    console.error('Error updating report:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ============ BLOCK USER ============

// Block a user
router.post('/users/:userId/block', authenticateToken, async (req, res) => {
  try {
    const blocker_id = req.user.id;
    const blocked_id = parseInt(req.params.userId);

    if (blocker_id === blocked_id) {
      return res.status(400).json({ success: false, message: 'You cannot block yourself' });
    }

    // Check if already blocked
    const [existing] = await db.query(
      'SELECT id FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
      [blocker_id, blocked_id]
    );

    if (existing.length > 0) {
      return res.status(400).json({ success: false, message: 'User is already blocked' });
    }

    // Create block
    await db.query(
      'INSERT INTO blocked_users (blocker_id, blocked_id, created_at) VALUES (?, ?, NOW())',
      [blocker_id, blocked_id]
    );

    res.json({ success: true, message: 'User blocked successfully' });
  } catch (error) {
    console.error('Error blocking user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Unblock a user
router.delete('/users/:userId/block', authenticateToken, async (req, res) => {
  try {
    const blocker_id = req.user.id;
    const blocked_id = parseInt(req.params.userId);

    await db.query(
      'DELETE FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
      [blocker_id, blocked_id]
    );

    res.json({ success: true, message: 'User unblocked successfully' });
  } catch (error) {
    console.error('Error unblocking user:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Get blocked users list
router.get('/users/blocked', authenticateToken, async (req, res) => {
  try {
    const [blockedUsers] = await db.query(
      `SELECT u.id, u.name, u.profile_photo_url, u.type, bu.created_at as blocked_at
       FROM blocked_users bu
       JOIN users u ON bu.blocked_id = u.id
       WHERE bu.blocker_id = ?
       ORDER BY bu.created_at DESC`,
      [req.user.id]
    );

    res.json({ success: true, data: blockedUsers });
  } catch (error) {
    console.error('Error fetching blocked users:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Check if user is blocked
router.get('/users/:userId/blocked', authenticateToken, async (req, res) => {
  try {
    const [result] = await db.query(
      'SELECT id FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
      [req.user.id, req.params.userId]
    );

    res.json({ success: true, data: { isBlocked: result.length > 0 } });
  } catch (error) {
    console.error('Error checking block status:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ============ ACCOUNT DELETION ============

// Delete account
router.delete('/delete-account', authenticateToken, async (req, res) => {

  try {
    const { password } = req.body;
    const userId = req.user.id;

    // Verify password
    const [user] = await db.query('SELECT password FROM users WHERE id = ?', [userId]);
    if (!user.length) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const bcrypt = require('bcryptjs');
    const isValidPassword = await bcrypt.compare(password, user[0].password);
    if (!isValidPassword) {
      return res.status(401).json({ success: false, message: 'Invalid password' });
    }

    // Start transaction for data deletion
    const connection = await db.getConnection();
    await connection.beginTransaction();

    try {
      // Delete user's data in order (respecting foreign keys)
      await connection.query('DELETE FROM notifications WHERE user_id = ?', [userId]);
      await connection.query('DELETE FROM messages WHERE sender_id = ?', [userId]);
      await connection.query('DELETE FROM reactions WHERE user_id = ?', [userId]);
      await connection.query('DELETE FROM comments WHERE user_id = ?', [userId]);
      await connection.query('DELETE FROM posts WHERE user_id = ?', [userId]);
      await connection.query('DELETE FROM follows WHERE follower_id = ? OR following_id = ?', [userId, userId]);
      await connection.query('DELETE FROM chats WHERE user1_id = ? OR user2_id = ?', [userId, userId]);
      await connection.query('DELETE FROM blocked_users WHERE blocker_id = ? OR blocked_id = ?', [userId, userId]);
      await connection.query('DELETE FROM reports WHERE reporter_id = ?', [userId]);
      await connection.query('DELETE FROM career_history WHERE user_id = ?', [userId]);
      
      // Finally delete the user
      await connection.query('DELETE FROM users WHERE id = ?', [userId]);

      await connection.commit();
      connection.release();

      res.json({ success: true, message: 'Account deleted successfully' });
    } catch (error) {
      await connection.rollback();
      connection.release();
      throw error;
    }
  } catch (error) {
    console.error('Error deleting account:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Accept terms of use
router.post('/auth/accept-terms', authenticateToken, async (req, res) => {
  try {
    await db.query(
      'UPDATE users SET terms_accepted = 1, terms_accepted_at = NOW() WHERE id = ?',
      [req.user.id]
    );

    res.json({ success: true, message: 'Terms accepted successfully' });
  } catch (error) {
    console.error('Error accepting terms:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;