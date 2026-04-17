const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const upload = require('../config/auth-upload');

const crypto = require("crypto");
const bcrypt = require("bcrypt");
const { sendResetEmail } = require("../utils/mailer");

// ✅ CHANGE THIS PATH to your real pool file:
const pool = require('../config/db'); // <-- edit this

// Auth routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/profile', authenticateToken, authController.getProfile);

router.post('/login-otp', authController.loginWithOtp);
router.post('/send-otp', authController.sendOtp);
router.post('/verify-otp', authController.verifyOtp);

// Profile update route with image uploads
router.put(
  '/update-profile',
  authenticateToken,
  upload.fields([
    { name: 'profile_photo', maxCount: 1 },
    { name: 'cover_photo', maxCount: 1 }
  ]),
  authController.updateProfile
);

function sha256(str) {
  return crypto.createHash("sha256").update(str).digest("hex");
}

// POST /api/auth/forgot-password
router.post("/forgot-password", async (req, res) => {
  const safeMsg = "If that email exists, we sent a reset link.";

  try {
    const email = String(req.body.email || "").trim().toLowerCase();

    if (!email || !email.includes("@")) {
      return res.json({ success: true, message: safeMsg });
    }

    // 1) Find user
    const [users] = await pool.query(
      "SELECT id, email FROM users WHERE email = ? LIMIT 1",
      [email]
    );

    const user = users[0];
    if (!user) {
      return res.json({ success: true, message: safeMsg });
    }

    // 2) Generate token
    const rawToken = crypto.randomBytes(32).toString("hex");
    const tokenHash = sha256(rawToken);

    // 3) Save token (hash only) - expires in 30 min
    await pool.query(
      "INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 MINUTE), 0)",
      [user.id, tokenHash]
    );

    // 4) Send email with HTTPS link
    const resetUrl = `https://squad-player.app/reset?token=${rawToken}`;
    await sendResetEmail({ to: user.email, resetUrl });

    return res.json({ success: true, message: safeMsg });
  } catch (e) {
    console.error("forgot-password error:", e);
    return res.json({ success: true, message: safeMsg });
  }
});

// POST /api/auth/reset-password
router.post("/reset-password", async (req, res) => {
  try {
    const token = String(req.body.token || "").trim();
    const newPassword = String(req.body.newPassword || "");

    if (!token || token.length < 20) {
      return res.status(400).json({ success: false, message: "Invalid token" });
    }
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ success: false, message: "Password too short" });
    }

    const tokenHash = sha256(token);

    // 1) Lookup token row
    const [rows] = await pool.query(
      `SELECT id, user_id FROM password_reset_tokens
       WHERE token_hash = ? AND used = 0 AND expires_at > NOW()
       ORDER BY id DESC LIMIT 1`,
      [tokenHash]
    );

    const row = rows[0];
    if (!row) {
      return res.status(400).json({ success: false, message: "Token expired or invalid" });
    }

    // 2) Update user password
    const passwordHash = await bcrypt.hash(newPassword, 10);
    await pool.query("UPDATE users SET password = ? WHERE id = ?", [passwordHash, row.user_id]);

    // 3) Mark token used
    await pool.query("UPDATE password_reset_tokens SET used = 1 WHERE id = ?", [row.id]);

    return res.json({ success: true, message: "Password updated successfully" });
  } catch (e) {
    console.error("reset-password error:", e);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

module.exports = router;