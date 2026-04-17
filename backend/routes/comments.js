const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/authMiddleware'); // ✅ FIX

const {
  addComment,
  getComments,
  getCommentCount,
  deleteComment,
  updateComment,
  hideComment,
  unhideComment,
  reactToComment,      // ✅ add
  removeCommentReaction,      // ✅ add
} = require('../controllers/commentController');

router.post('/:postId', authenticateToken, addComment);

// IMPORTANT: protect reading too, because getComments uses req.user
router.get('/:postId', authenticateToken, getComments);

router.get('/:postId/count', getCommentCount);
// ✅ reactions
router.post('/:commentId/reaction', authenticateToken, reactToComment);
router.delete('/:commentId/reaction', authenticateToken, removeCommentReaction);

router.patch('/:commentId/hide', authenticateToken, hideComment);
router.patch('/:commentId/unhide', authenticateToken, unhideComment);

router.put('/:commentId', authenticateToken, updateComment);
router.delete('/:commentId', authenticateToken, deleteComment);

module.exports = router;
