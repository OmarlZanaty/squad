const db = require('../db');
const notificationController = require('./notificationController'); // Import notification controller


exports.getComments = async (req, res) => {
  const postId = Number(req.params.postId);
  const requesterId = req.user?.id ? Number(req.user.id) : null; // if you allow guest, adjust
  const requesterType = req.user?.type || null;

  try {
    // 1) Who owns the post?
    const [postRows] = await db.query(
      "SELECT user_id FROM posts WHERE id = ? LIMIT 1",
      [postId]
    );
    if (!postRows.length) return res.status(404).json({ message: "Post not found" });

    const postOwnerId = Number(postRows[0].user_id);
    const isPostOwner = requesterId && requesterId === postOwnerId;
    const isAdmin = requesterType === "admin";

    // 2) Build query based on who is requesting
    const whereVisibility = (isPostOwner || isAdmin)
      ? "1=1" // post owner/admin sees all
      : "c.status = 'active'"; // everyone else sees only active

 const sql = `
  SELECT 
    c.id, c.post_id, c.parent_comment_id, c.user_id, c.comment_text, c.created_at,
    u.name AS user_name,
    u.profile_photo_url AS user_photo,
    u.type AS user_type,
    c.status,
    CASE WHEN c.status='hidden' THEN 1 ELSE 0 END AS is_hidden,

    (SELECT COUNT(*) FROM comments r WHERE r.parent_comment_id = c.id) AS repliesCount,

    (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='like') AS likesCount,
    (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='dislike') AS dislikesCount,

    ${
      requesterId
        ? `(SELECT cr.reaction FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.user_id = ? LIMIT 1) AS myReaction`
        : `NULL AS myReaction`
    }

  FROM comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.post_id = ?
    AND ${whereVisibility}
  ORDER BY c.created_at ASC
`;


const params = [];
if (requesterId) params.push(requesterId);
params.push(postId);

const [comments] = await db.query(sql, params);
    return res.status(200).json(comments);
  } catch (error) {
    console.error("❌ Get Comments Error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.reactToComment = async (req, res) => {
  const commentId = Number(req.params.commentId);
  const userId = Number(req.user.id);
  const { reaction } = req.body; // 'like' or 'dislike'

  if (!['like', 'dislike'].includes(reaction)) {
    return res.status(400).json({ message: "reaction must be 'like' or 'dislike'" });
  }

  try {
    // upsert (unique comment_id,user_id)
    await db.query(
      `
      INSERT INTO comment_reactions (comment_id, user_id, reaction)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE reaction = VALUES(reaction)
      `,
      [commentId, userId, reaction]
    );

    // return updated counts + myReaction
    const [rows] = await db.query(
      `
      SELECT
        (SELECT COUNT(*) FROM comment_reactions WHERE comment_id=? AND reaction='like') AS likesCount,
        (SELECT COUNT(*) FROM comment_reactions WHERE comment_id=? AND reaction='dislike') AS dislikesCount,
        (SELECT reaction FROM comment_reactions WHERE comment_id=? AND user_id=? LIMIT 1) AS myReaction
      `,
      [commentId, commentId, commentId, userId]
    );

    return res.status(200).json(rows[0]);
  } catch (e) {
    console.error("reactToComment error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.removeCommentReaction = async (req, res) => {
  const commentId = Number(req.params.commentId);
  const userId = Number(req.user.id);

  try {
    await db.query(
      `DELETE FROM comment_reactions WHERE comment_id=? AND user_id=?`,
      [commentId, userId]
    );

    const [rows] = await db.query(
      `
      SELECT
        (SELECT COUNT(*) FROM comment_reactions WHERE comment_id=? AND reaction='like') AS likesCount,
        (SELECT COUNT(*) FROM comment_reactions WHERE comment_id=? AND reaction='dislike') AS dislikesCount,
        NULL AS myReaction
      `,
      [commentId, commentId]
    );

    return res.status(200).json(rows[0]);
  } catch (e) {
    console.error("removeCommentReaction error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};


exports.hideComment = async (req, res) => {
  const commentId = Number(req.params.commentId);
  const userId = Number(req.user.id);
  const userType = req.user.type;

  try {
    const [rows] = await db.query(
      `SELECT c.id, c.post_id, p.user_id AS post_owner_id
       FROM comments c
       JOIN posts p ON p.id = c.post_id
       WHERE c.id = ?
       LIMIT 1`,
      [commentId]
    );

    if (!rows.length) return res.status(404).json({ message: "Comment not found" });

    const isPostOwner = Number(rows[0].post_owner_id) === userId;
    const isAdmin = userType === "admin";

    if (!isPostOwner && !isAdmin) {
      return res.status(403).json({ message: "Not allowed" });
    }

    await db.query("UPDATE comments SET status='hidden' WHERE id=?", [commentId]);
    return res.status(200).json({ success: true, status: "hidden" });
  } catch (e) {
    console.error("hideComment error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.unhideComment = async (req, res) => {
  const commentId = Number(req.params.commentId);
  const userId = Number(req.user.id);
  const userType = req.user.type;

  try {
    const [rows] = await db.query(
      `SELECT c.id, c.post_id, p.user_id AS post_owner_id
       FROM comments c
       JOIN posts p ON p.id = c.post_id
       WHERE c.id = ?
       LIMIT 1`,
      [commentId]
    );

    if (!rows.length) return res.status(404).json({ message: "Comment not found" });

    const isPostOwner = Number(rows[0].post_owner_id) === userId;
    const isAdmin = userType === "admin";

    if (!isPostOwner && !isAdmin) {
      return res.status(403).json({ message: "Not allowed" });
    }

    await db.query("UPDATE comments SET status='active' WHERE id=?", [commentId]);
    return res.status(200).json({ success: true, status: "active" });
  } catch (e) {
    console.error("unhideComment error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.addComment = async (req, res) => {
  const { postId } = req.params;
  const userId = req.user.id;
  const { comment_text, parent_comment_id } = req.body;

  if (!comment_text || comment_text.trim() === '') {
    return res.status(400).json({ message: 'Comment text is required.' });
  }

  try {
    const pid = parent_comment_id ? Number(parent_comment_id) : null;

    // ✅ If reply: validate parent belongs to same post
    if (pid) {
      const [parentRows] = await db.query(
        `SELECT id, post_id FROM comments WHERE id = ? LIMIT 1`,
        [pid]
      );
      if (!parentRows.length) {
        return res.status(404).json({ message: "Parent comment not found" });
      }
      if (Number(parentRows[0].post_id) !== Number(postId)) {
        return res.status(400).json({ message: "Parent comment not in this post" });
      }
    }

    const insertSql =
      'INSERT INTO comments (post_id, parent_comment_id, user_id, comment_text) VALUES (?, ?, ?, ?)';
    const [result] = await db.query(insertSql, [
      Number(postId),
      pid,
      userId,
      comment_text.trim(),
    ]);

    const selectSql = `
      SELECT 
        c.id, c.post_id, c.parent_comment_id, c.user_id, c.comment_text, c.created_at,
        u.name as user_name,
        u.profile_photo_url as user_photo,
        u.type as user_type,

        (SELECT COUNT(*) FROM comments r WHERE r.parent_comment_id = c.id) AS repliesCount,

        (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='like') AS likesCount,
        (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='dislike') AS dislikesCount,

        (SELECT cr.reaction FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.user_id = ? LIMIT 1) AS myReaction
      FROM comments c
      JOIN users u ON c.user_id = u.id
      WHERE c.id = ?
      LIMIT 1
    `;
    const [rows] = await db.query(selectSql, [userId, result.insertId]);

    // --- NOTIFICATION LOGIC ---
    // if it's a reply: notify parent comment owner (optional)
    // else: notify post owner (your existing logic)
    try {
      if (pid) {
        const [parentOwnerRows] = await db.query(
          "SELECT user_id FROM comments WHERE id = ? LIMIT 1",
          [pid]
        );
        if (parentOwnerRows.length) {
          const parentOwnerId = Number(parentOwnerRows[0].user_id);
          if (parentOwnerId !== userId) {
            await notificationController.createNotification(parentOwnerId, userId, 'reply', postId);
          }
        }
      } else {
        const [posts] = await db.query("SELECT user_id FROM posts WHERE id = ?", [postId]);
        if (posts.length > 0) {
          const postOwnerId = Number(posts[0].user_id);
          if (postOwnerId !== userId) {
            await notificationController.createNotification(postOwnerId, userId, 'comment', postId);
          }
        }
      }
    } catch (notifError) {
      console.error("Notification Error (Non-fatal):", notifError);
    }

    return res.status(201).json(rows[0]);
  } catch (error) {
    console.error('Add Comment Error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
};


exports.deleteComment = async (req, res) => {
  const { commentId } = req.params;
  const userId = req.user.id;
  const userType = req.user.type; // from JWT payload

  try {
    // get comment + post owner
    const [rows] = await db.query(
      `SELECT c.id, c.user_id AS comment_owner_id, c.post_id, p.user_id AS post_owner_id
       FROM comments c
       JOIN posts p ON p.id = c.post_id
       WHERE c.id = ?
       LIMIT 1`,
      [commentId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: 'Comment not found.' });
    }

    const c = rows[0];

    const isCommentOwner = Number(c.comment_owner_id) === Number(userId);
    const isPostOwner = Number(c.post_owner_id) === Number(userId);
    const isAdmin = userType === 'admin';

    if (!isCommentOwner && !isPostOwner && !isAdmin) {
      return res.status(403).json({ message: 'Not allowed to delete this comment.' });
    }

    await db.query('DELETE FROM comments WHERE id = ?', [commentId]);
    return res.status(200).json({ message: 'Comment deleted successfully.' });
  } catch (error) {
    console.error('Delete Comment Error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
};



exports.updateComment = async (req, res) => {
  try {
    const commentId = Number(req.params.commentId);
    const { comment_text } = req.body;

    if (!comment_text || !comment_text.trim()) {
      return res.status(400).json({ message: "comment_text is required" });
    }

    const [rows] = await db.query(
      "SELECT id, user_id FROM comments WHERE id = ? LIMIT 1",
      [commentId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Comment not found" });
    }

    const comment = rows[0];
    const userId = req.user.id;
    const userType = req.user.type; // optional

    if (comment.user_id !== userId && userType !== "admin") {
      return res.status(403).json({ message: "Not allowed" });
    }

    await db.query(
      "UPDATE comments SET comment_text = ? WHERE id = ?",
      [comment_text.trim(), commentId]
    );

    const [updatedRows] = await db.query(
  `
  SELECT 
    c.id, c.post_id, c.parent_comment_id, c.user_id, c.comment_text, c.created_at,
    u.name AS user_name,
    u.profile_photo_url AS user_photo,
    u.type AS user_type,

    (SELECT COUNT(*) FROM comments r WHERE r.parent_comment_id = c.id) AS repliesCount,
    (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='like') AS likesCount,
    (SELECT COUNT(*) FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.reaction='dislike') AS dislikesCount,
    (SELECT cr.reaction FROM comment_reactions cr WHERE cr.comment_id = c.id AND cr.user_id = ? LIMIT 1) AS myReaction
  FROM comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.id = ?
  LIMIT 1
  `,
  [userId, commentId]
);

return res.status(200).json(updatedRows[0]);

  } catch (e) {
    console.error("updateComment error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.getCommentCount = async (req, res) => {
  const { postId } = req.params;
  try {
    const sql = 'SELECT COUNT(*) as comment_count FROM comments WHERE post_id = ?';
    const [result] = await db.query(sql, [postId]);
    res.status(200).json({ comment_count: result[0].comment_count });
  } catch (error) {
    console.error('Get Comment Count Error:', error);
    res.status(500).json({ message: 'Server error' });
  }
};