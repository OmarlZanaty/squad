const express = require("express");
const router = express.Router();

const userController = require("../controllers/userController");
const { authenticateToken } = require("../middleware/authMiddleware");

// Search users - MUST BE BEFORE /:id routes!
router.get("/search", authenticateToken, userController.searchUsers);

router.get("/players", authenticateToken, userController.getPlayers);

// Most viewed
router.get("/most-viewed", authenticateToken, userController.getMostViewedPlayers);

// Track profile view
router.post("/:id/view", authenticateToken, userController.trackProfileView);

router.get('/most-active', authenticateToken, userController.getMostActivePlayers);
// Get posts by specific user (put BEFORE /:id)
router.get("/:id/posts", userController.getUserPosts);

// Followers / following
router.get("/:id/followers", userController.getFollowers);

router.get("/:id/following", userController.getFollowing);

// Follow / unfollow
router.post("/:id/follow", authenticateToken, userController.followUser);
router.post("/:id/unfollow", authenticateToken, userController.unfollowUser);

// Get user profile by ID (keep LAST)
router.get("/:id", authenticateToken, userController.getUserProfile);


module.exports = router;
