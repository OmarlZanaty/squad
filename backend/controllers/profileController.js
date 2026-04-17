const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

exports.shareProfile = async (req, res) => {
  try {

    const profileUserId = req.params.id;
    const userId = req.user.id;

    const platform = req.body?.platform || "system";

    console.log("PROFILE SHARE", {
      profileUserId,
      userId,
      platform
    });

    await db.query(`
      INSERT INTO profile_shares (profile_user_id, shared_by, platform)
      VALUES (?, ?, ?)
    `, [profileUserId, userId, platform]);

    res.json({
      success: true,
      message: "Profile share recorded"
    });

  } catch (err) {

    console.error("Profile share error:", err);

    res.status(500).json({
      success: false,
      message: "Failed to record profile share"
    });

  }
};