const express = require('express');
const router = express.Router();
const postController = require('../controllers/postController');
const { authenticateToken } = require('../middleware/authMiddleware');
const upload = require('../config/storage');

// POST /api/posts/upload
router.post('/upload', authenticateToken, upload.single('media'), postController.createPost);

// GET /api/posts - Get all posts
router.get('/', authenticateToken, postController.getPosts); // Added authenticateToken to get current user ID for hide/pin logic

// GET /api/posts/:id - Get single post by ID
router.get('/:id', authenticateToken, postController.getPostById); // Added authenticateToken

// POST /api/posts/:id/react - React to a post
router.post('/:id/react', authenticateToken, postController.reactToPost);

// POST /api/posts/:id/view - Increment view count
router.post('/:id/view', postController.incrementView);

// POST /api/posts/:id/view - Increment view count
router.post('/:id/view', postController.incrementView);

// POST /api/posts/:id/share - Record share
router.post('/:id/share', authenticateToken, postController.sharePost);


// PUT /api/posts/:id - Update a post
router.put('/:id', authenticateToken, upload.single('media'), postController.updatePost);

// DELETE /api/posts/:id - Delete a post
router.delete('/:id', authenticateToken, postController.deletePost);

// POST /api/posts/:id/pin - Toggle pin status
router.post('/:id/pin', authenticateToken, postController.togglePin);

// POST /api/posts/:id/hide - Toggle hide status
router.post('/:id/hide', authenticateToken, postController.toggleHide);

module.exports = router;