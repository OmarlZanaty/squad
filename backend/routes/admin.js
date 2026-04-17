const express = require("express");
const router = express.Router();
const adminAuth = require("../middleware/adminAuth");
const db = require("../db");
const bcrypt = require("bcryptjs");
router.use(adminAuth);

/* =========================
   USERS
========================= */
function adminKeyMiddleware(req, res, next) {
  const key = req.headers["x-admin-key"];
  const expected = process.env.ADMIN_KEY; // recommended to store in .env

  if (!expected) {
    return res.status(500).json({ success: false, message: "ADMIN_KEY not configured" });
  }

  if (!key || key !== expected) {
    return res.status(401).json({ success: false, message: "Unauthorized" });
  }

  next();
}

router.patch("/users/:id/password", adminKeyMiddleware, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const newPass = (req.body?.new_password || "").toString();

    if (!Number.isFinite(id) || id <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user id" });
    }
    if (newPass.length < 6) {
      return res.status(400).json({ success: false, message: "Password too short (min 6)" });
    }

    // ✅ hash and save in users.password
    const hash = await bcrypt.hash(newPass, 10);

    await db.query("UPDATE users SET password = ? WHERE id = ?", [hash, id]);

    return res.json({ success: true, message: "Password updated" });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});

router.patch("/users/:id/vip", adminKeyMiddleware, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const raw = req.body?.is_vip;

    if (!Number.isFinite(id) || id <= 0) {
      return res.status(400).json({ success: false, message: "Invalid user id" });
    }

    let vipVal = null;
    if (raw === 0 || raw === 1) vipVal = raw;
    else if (raw === true) vipVal = 1;
    else if (raw === false) vipVal = 0;

    if (vipVal === null) {
      return res.status(400).json({ success: false, message: "is_vip must be 0/1" });
    }

    // ✅ IMPORTANT: use db not pool
    // ✅ IMPORTANT: use db not pool
await db.query("UPDATE users SET is_vip = ? WHERE id = ?", [vipVal, id]);

const [rows] = await db.query(`
  SELECT
    u.id, u.name, u.email, u.type, u.status, u.is_vip,
    COALESCE(p.rating, 0) as rating
  FROM users u
  LEFT JOIN players p ON p.user_id = u.id
  WHERE u.id = ?
  LIMIT 1
`, [id]);

return res.json({ success: true, data: rows[0] });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ success: false, message: "Server error" });
  }
});
// GET all users with pagination and filters
router.get("/users", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const status = req.query.status || '';
    const type = req.query.type || '';
    const search = req.query.search || '';
const isVip = req.query.is_vip;

    let whereClause = [];
    let params = [];

    // Always filter for phone_verified = 1
    whereClause.push("u.phone_verified = ?");
    params.push(1);

    if (status) {
      whereClause.push("u.status = ?");
      params.push(status);
    }

    if (type) {
      whereClause.push("u.type = ?");
      params.push(type);
    }

    if (search) {
  whereClause.push("(u.name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)");
  params.push(`%${search}%`, `%${search}%`, `%${search}%`);
}

    if (isVip === '0' || isVip === '1') {
  whereClause.push("u.is_vip = ?");
  params.push(Number(isVip));
}

const whereSQL = whereClause.length > 0 
  ? "WHERE " + whereClause.join(" AND ")
  : "";
    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM users u ${whereSQL}`;
    const [[{ total }]] = await db.query(countQuery, params);

    // Get paginated data
    const query = `
      SELECT
        u.id, u.name, u.email, u.phone, u.phone_verified, u.type, u.status, u.is_vip,
        u.profile_photo_url, u.cover_photo_url, 
        COALESCE(p.country) as country, 
        COALESCE(p.position) as position, 
        COALESCE(p.bio) as bio,
        COALESCE(p.current_club) as current_club, 
        COALESCE(p.rating) as rating, 
        COALESCE(p.height) as height, 
        COALESCE(p.weight) as weight, 
        COALESCE(p.age) as age,
        COALESCE(p.full_name) as full_name, 
        COALESCE(p.birth_date) as birth_date,
        u.created_at
      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      ${whereSQL}
      ORDER BY u.id DESC
      LIMIT ? OFFSET ?
    `;

    const [rows] = await db.query(query, [...params, limit, offset]);

    res.json({ 
      success: true, 
      data: rows,
      total: total,
      limit: limit,
      offset: offset
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET single user with all details
router.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    
    // Validate that id is a valid number
    if (!id || id === 'null' || isNaN(parseInt(id))) {
      return res.status(400).json({ success: false, message: "Invalid user ID" });
    }

    const [rows] = await db.query(`
      SELECT
    u.id, u.name, u.email, u.phone, u.phone_verified, u.type, u.status, u.is_vip,
    u.profile_photo_url, u.cover_photo_url,
        COALESCE(p.country) as country, 
        COALESCE(p.position) as position, 
        COALESCE(p.bio) as bio,
        COALESCE(p.current_club) as current_club, 
        COALESCE(p.rating) as rating, 
        COALESCE(p.height) as height, 
        COALESCE(p.weight) as weight, 
        COALESCE(p.age) as age,
        COALESCE(p.full_name) as full_name, 
        COALESCE(p.birth_date) as birth_date,
        u.created_at
      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.id = ?
    `, [req.params.id]);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE user
router.put("/users/:id", async (req, res) => {
  const { name, status, type, country, position, bio, current_club, rating, height, weight, age, full_name, birth_date } = req.body;

  try {
    const userUpdateFields = [];
    const userValues = [];
    const playerUpdateFields = [];
    const playerValues = [];

    if (name !== undefined) {
      userUpdateFields.push("name = ?");
      userValues.push(name);
    }
    if (status !== undefined) {
      userUpdateFields.push("status = ?");
      userValues.push(status);
    }
    if (type !== undefined) {
      userUpdateFields.push("type = ?");
      userValues.push(type);
    }
    if (country !== undefined) {
      playerUpdateFields.push("country = ?");
      playerValues.push(country);
    }
    if (position !== undefined) {
      playerUpdateFields.push("position = ?");
      playerValues.push(position);
    }
    if (bio !== undefined) {
      playerUpdateFields.push("bio = ?");
      playerValues.push(bio);
    }
    if (current_club !== undefined) {
      playerUpdateFields.push("current_club = ?");
      playerValues.push(current_club);
    }
    if (rating !== undefined) {
      playerUpdateFields.push("rating = ?");
      playerValues.push(rating);
    }
    if (height !== undefined) {
      playerUpdateFields.push("height = ?");
      playerValues.push(height);
    }
    if (weight !== undefined) {
      playerUpdateFields.push("weight = ?");
      playerValues.push(weight);
    }
    if (age !== undefined) {
      playerUpdateFields.push("age = ?");
      playerValues.push(age);
    }
    if (full_name !== undefined) {
      playerUpdateFields.push("full_name = ?");
      playerValues.push(full_name);
    }
    if (birth_date !== undefined) {
      playerUpdateFields.push("birth_date = ?");
      playerValues.push(birth_date);
    }

    if (userUpdateFields.length > 0) {
      userValues.push(req.params.id);
      const userQuery = `UPDATE users SET ${userUpdateFields.join(", ")} WHERE id = ?`;
      await db.query(userQuery, userValues);
    }

    if (playerUpdateFields.length > 0) {
      playerValues.push(req.params.id);
      const playerQuery = `UPDATE players SET ${playerUpdateFields.join(", ")} WHERE user_id = ?`;
      await db.query(playerQuery, playerValues);
    }

    if (userUpdateFields.length === 0 && playerUpdateFields.length === 0) {
      return res.json({ success: true, message: "No fields to update" });
    }

    res.json({ success: true, message: "User updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// BAN user (soft)
router.post("/users/:id/ban", async (req, res) => {
  try {
    await db.query(
      `UPDATE users SET status='pending' WHERE id=?`,
      [req.params.id]
    );

    res.json({ success: true, message: "User banned successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* =========================
   POSTS
========================= */

// GET all posts with pagination and filters
router.get("/posts", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const status = req.query.status || '';
    const user_id = req.query.user_id || ''; // ← ADD THIS

    let whereClause = [];
    let params = [];

    if (status) {
      whereClause.push("p.status = ?");
      params.push(status);
    }

    if (user_id) { // ← ADD THIS BLOCK
      whereClause.push("p.user_id = ?");
      params.push(user_id);
    }

    const whereSQL = whereClause.length > 0 ? "WHERE " + whereClause.join(" AND ") : "";

    const countQuery = `SELECT COUNT(*) as total FROM posts p ${whereSQL}`;
    const [[{ total }]] = await db.query(countQuery, params);

    const query = `
      SELECT 
        p.id, p.user_id, p.media_type, p.media_url, p.caption, 
        p.created_at, p.comment_count, p.status, p.views, 
        p.is_pinned, p.is_hidden,
        u.name AS user_name, u.profile_photo_url
      FROM posts p
      JOIN users u ON u.id = p.user_id
      ${whereSQL}
      ORDER BY p.id DESC
      LIMIT ? OFFSET ?
    `;

    const [rows] = await db.query(query, [...params, limit, offset]);

    res.json({ 
      success: true, 
      data: rows,
      total: total,
      limit: limit,
      offset: offset
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET single post with all details
router.get("/posts/:id", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        p.id, p.user_id, p.media_type, p.media_url, p.caption, 
        p.created_at, p.comment_count, p.status, p.views, 
        p.is_pinned, p.is_hidden,
        u.name AS user_name, u.profile_photo_url
      FROM posts p
      JOIN users u ON u.id = p.user_id
      WHERE p.id = ?
    `, [req.params.id]);

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: "Post not found" });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE post
router.put("/posts/:id", async (req, res) => {
  const { status, caption, is_pinned, is_hidden } = req.body;

  try {
    const updateFields = [];
    const values = [];

    if (status !== undefined) {
      updateFields.push("status = ?");
      values.push(status);
    }
    if (caption !== undefined) {
      updateFields.push("caption = ?");
      values.push(caption);
    }
    if (is_pinned !== undefined) {
      updateFields.push("is_pinned = ?");
      values.push(is_pinned ? 1 : 0);
    }
    if (is_hidden !== undefined) {
      updateFields.push("is_hidden = ?");
      values.push(is_hidden ? 1 : 0);
    }

    if (updateFields.length === 0) {
      return res.json({ success: true, message: "No fields to update" });
    }

    values.push(req.params.id);

    const query = `UPDATE posts SET ${updateFields.join(", ")} WHERE id = ?`;
    await db.query(query, values);

    res.json({ success: true, message: "Post updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE post
router.delete("/posts/:id", async (req, res) => {
  try {
    await db.query(`DELETE FROM posts WHERE id=?`, [req.params.id]);
    res.json({ success: true, message: "Post deleted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* =========================
   COMMENTS
========================= */


// GET all comments with pagination
router.get("/comments", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;

    // Get total count
    const [[{ total }]] = await db.query("SELECT COUNT(*) as total FROM comments");

    // Get paginated data
    const [rows] = await db.query(`
      SELECT 
        c.id, c.user_id, c.post_id, c.comment_text, c.created_at,
        u.name AS user_name, u.profile_photo_url
      FROM comments c
      JOIN users u ON u.id = c.user_id
      ORDER BY c.id DESC
      LIMIT ? OFFSET ?
    `, [limit, offset]);

    res.json({ 
      success: true, 
      data: rows,
      total: total,
      limit: limit,
      offset: offset
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE comment
router.put("/comments/:id", async (req, res) => {
  const { status } = req.body;

  try {
    await db.query(
      `UPDATE comments SET status = ? WHERE id = ?`,
      [status, req.params.id]
    );

    res.json({ success: true, message: "Comment updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE comment
router.delete("/comments/:id", async (req, res) => {
  try {
    await db.query(`DELETE FROM comments WHERE id = ?`, [req.params.id]);
    res.json({ success: true, message: "Comment deleted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* =========================
   REPORTS
========================= */

// GET all reports with pagination
router.get("/reports", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;
    const status = req.query.status || '';

    let whereClause = [];
    let params = [];

    if (status) {
      whereClause.push("r.status = ?");
      params.push(status);
    }

    const whereSQL = whereClause.length > 0 ? "WHERE " + whereClause.join(" AND ") : "";

    // Get total count
    const countQuery = `SELECT COUNT(*) as total FROM reports r ${whereSQL}`;
    const [[{ total }]] = await db.query(countQuery, params);

    // Get paginated data
    const [rows] = await db.query(`
      SELECT 
        r.id, r.reporter_id, r.content_type, r.content_id, 
        r.reason, r.status, r.created_at,
        u.name AS reporter_name
      FROM reports r
      LEFT JOIN users u ON u.id = r.reporter_id
      ${whereSQL}
      ORDER BY r.id DESC
      LIMIT ? OFFSET ?
    `, [...params, limit, offset]);

    res.json({ 
      success: true, 
      data: rows,
      total: total,
      limit: limit,
      offset: offset
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE report
router.put("/reports/:id", async (req, res) => {
  const { status } = req.body;

  try {
    await db.query(
      `UPDATE reports SET status = ? WHERE id = ?`,
      [status, req.params.id]
    );

    res.json({ success: true, message: "Report updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE report
router.delete("/reports/:id", async (req, res) => {
  try {
    await db.query(`DELETE FROM reports WHERE id = ?`, [req.params.id]);
    res.json({ success: true, message: "Report deleted successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

/* =========================
   AUDIT LOGS
========================= */

// GET all audit logs with pagination
router.get("/audit", async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const offset = parseInt(req.query.offset) || 0;

    // Get total count
    const [[{ total }]] = await db.query("SELECT COUNT(*) as total FROM activity_logs");

    // Get paginated data
    const [rows] = await db.query(`
      SELECT 
        activity_logs.id, adminId, action, details, activity_logs.createdAt,
        u.name AS admin_name
      FROM activity_logs
      LEFT JOIN admin_users u ON u.id = adminId
      ORDER BY activity_logs.id DESC
      LIMIT ? OFFSET ?
    `, [limit, offset]);

    res.json({ 
      success: true, 
      data: rows,
      total: total,
      limit: limit,
      offset: offset
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;