const db = require('../db');

// Helper function to ensure columns exist
const ensureMessageColumns = async () => {
    try {
        await db.query(`
            ALTER TABLE messages 
            ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS deleted_by_sender BOOLEAN DEFAULT FALSE
        `);
    } catch (error) {
        // Ignore duplicate column errors or other non-critical migration issues
        // console.log('Migration note:', error.message);
    }
};

// Helper: ensure block/report tables exist (safe on every boot)
const ensureBlockAndReportTables = async () => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS user_blocks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        blocker_id INT NOT NULL,
        blocked_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_block (blocker_id, blocked_id)
      )
    `);

    await db.query(`
      CREATE TABLE IF NOT EXISTS user_reports (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reporter_id INT NOT NULL,
        reported_user_id INT NOT NULL,
        chat_id INT NULL,
        reason VARCHAR(255) NULL,
        details TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
  } catch (e) {
    // do not crash server if migration fails
    // console.log("ensureBlockAndReportTables warning:", e.message);
  }
};

// Helper: check if two users are blocked (either direction)
async function isBlockedBetween(userA, userB) {
  const [rows] = await db.query(
    `
    SELECT id FROM user_blocks
    WHERE (blocker_id = ? AND blocked_id = ?)
       OR (blocker_id = ? AND blocked_id = ?)
    LIMIT 1
    `,
    [userA, userB, userB, userA]
  );

  return rows.length > 0;
}

// ===== Block helpers =====
async function isBlockedEitherWay(db, userA, userB) {
  // blocked_users table: blocker_id, blocked_id
  const [rows] = await db.query(
    `SELECT 1
     FROM blocked_users
     WHERE (blocker_id = ? AND blocked_id = ?)
        OR (blocker_id = ? AND blocked_id = ?)
     LIMIT 1`,
    [userA, userB, userB, userA]
  );

  return rows.length > 0;
}

exports.startChat = async (req, res) => {
    const userId = req.user.id;
    const { other_user_id } = req.body;

    if (!other_user_id) {
        return res.status(400).json({ message: "other_user_id is required." });
    }

    if (userId == other_user_id) {
        return res.status(400).json({ message: "You cannot start a chat with yourself." });
    }

    try {
        // Ensure user1_id is always the smaller ID to avoid duplicate chats
        const user1_id = Math.min(userId, other_user_id);
        const user2_id = Math.max(userId, other_user_id);

        // 🚫 Block check (either direction)
        await ensureBlockAndReportTables();
        const blocked = await isBlockedBetween(userId, other_user_id);
        if (blocked) {
          return res.status(403).json({ message: "You cannot start a chat with this user." });
        }

        // Check if chat already exists
        const [existingChats] = await db.query(
            "SELECT id FROM chats WHERE user1_id = ? AND user2_id = ?",
            [user1_id, user2_id]
        );

        if (existingChats.length > 0) {
            return res.status(200).json({ 
                message: "Chat already exists.", 
                chat_id: existingChats[0].id 
            });
        }

        // Create new chat
        const [result] = await db.query(
            "INSERT INTO chats (user1_id, user2_id) VALUES (?, ?)",
            [user1_id, user2_id]
        );

        res.status(201).json({ 
            message: "Chat created successfully.", 
            chat_id: result.insertId 
        });

    } catch (error) {
        console.error("Start Chat Error:", error);
        res.status(500).json({ message: "Server error while starting chat." });
    }
};

exports.sendMessage = async (req, res) => {
    const userId = req.user.id;
    const { id: chatId } = req.params;
    const { message } = req.body;

    console.log('📤 [SEND MESSAGE] Request received');
    console.log('   User ID:', userId);
    console.log('   Chat ID:', chatId);
    console.log('   Message:', message);

    if (!message || message.trim() === '') {
        console.log('❌ [SEND MESSAGE] Empty message rejected');
        return res.status(400).json({ message: "Message cannot be empty." });
    }

    try {
        // Verify user is part of this chat
        const [chats] = await db.query(
            "SELECT user1_id, user2_id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
            [chatId, userId, userId]
        );

        if (chats.length === 0) {
            console.log('❌ [SEND MESSAGE] User not participant in chat');
            return res.status(403).json({ message: "You are not a participant in this chat." });
        }


        const chat = chats[0];
        const otherUserId = chat.user1_id === userId ? chat.user2_id : chat.user1_id;

        await ensureBlockAndReportTables();
if (await isBlockedBetween(userId, otherUserId)) {
  return res.status(403).json({ message: "You cannot message this user." });
}


        console.log('✅ [SEND MESSAGE] Chat verified');
        console.log('   Sender ID:', userId);
        console.log('   Receiver ID:', otherUserId);

        // Insert message
        const [result] = await db.query(
            "INSERT INTO messages (chat_id, sender_id, message) VALUES (?, ?, ?)",
            [chatId, userId, message]
        );

        console.log('✅ [SEND MESSAGE] Message saved to database');
        console.log('   Message ID:', result.insertId);
        console.log('   From User:', userId, '→ To User:', otherUserId);

        res.status(201).json({ message: "Message sent successfully." });

    } catch (error) {
        console.error("Send Message Error:", error);
        res.status(500).json({ message: "Server error while sending message." });
    }
};

exports.getMessages = async (req, res) => {
    const userId = req.user.id;
    const { id: chatId } = req.params;
    const { since } = req.query; // Optional: timestamp to fetch only new messages

    console.log('📥 [GET MESSAGES] Request received');
    console.log('   User ID:', userId);
    console.log('   Chat ID:', chatId);
    console.log('   Since:', since || 'all messages');

    try {
        // Verify user is part of this chat
        const [chats] = await db.query(
            "SELECT user1_id, user2_id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
            [chatId, userId, userId]
        );

        if (chats.length === 0) {
            console.log('❌ [GET MESSAGES] User not participant in chat');
            return res.status(403).json({ message: "You are not a participant in this chat." });
        }


        const chat = chats[0];
        const otherUserId = chat.user1_id === userId ? chat.user2_id : chat.user1_id;

        await ensureBlockAndReportTables();
if (await isBlockedBetween(userId, otherUserId)) {
  return res.status(403).json({ message: "You cannot view messages with this user." });
}

        console.log('✅ [GET MESSAGES] Chat verified');
        console.log('   Requester ID:', userId);
        console.log('   Other User ID:', otherUserId);

        // Ensure columns exist (migration check)
        await ensureMessageColumns();

        // Check if columns actually exist in the database schema before querying
        // This is a safety check because ALTER TABLE might fail silently or be async in some DB configs
        // or if the user hasn't restarted the server properly
        
        // We'll try to select all columns. If it fails, we fallback to basic columns
        try {
  let sql = `
    SELECT 
      m.id,
      m.sender_id,
      m.message,
      m.created_at,
      m.is_edited,
      m.is_pinned,
      u.name AS sender_name,
      u.profile_photo_url AS sender_photo
    FROM messages m
    JOIN users u ON m.sender_id = u.id
    WHERE m.chat_id = ?
      AND COALESCE(m.deleted_by_sender, FALSE) = FALSE
  `;

  const params = [chatId];

  if (since) {
    sql += ` AND m.created_at > ?`;
    params.push(since);
  }

  sql += ` ORDER BY m.created_at ASC`;

  const [messages] = await db.query(sql, params);

  console.log('✅ [GET MESSAGES] Messages retrieved');
  console.log('   Message count:', messages.length);

  return res.status(200).json(messages);
} catch (queryError) {
  console.error("Query Error (Retrying with basic columns):", queryError.message);

  let sql = `
    SELECT 
      m.id,
      m.sender_id,
      m.message,
      m.created_at,
      u.name AS sender_name,
      u.profile_photo_url AS sender_photo
    FROM messages m
    JOIN users u ON m.sender_id = u.id
    WHERE m.chat_id = ?
  `;

  const params = [chatId];

  if (since) {
    sql += ` AND m.created_at > ?`;
    params.push(since);
  }

  sql += ` ORDER BY m.created_at ASC`;

  const [messages] = await db.query(sql, params);

  const enrichedMessages = messages.map(msg => ({
    ...msg,
    is_edited: 0,
    is_pinned: 0
  }));

  return res.status(200).json(enrichedMessages);
}

        

    } catch (error) {
        console.error("Get Messages Error:", error);
        res.status(500).json({ message: "Server error while fetching messages." });
    }
};

exports.getChatList = async (req, res) => {
  const userId = req.user.id;
  const includeArchived = req.query.include_archived === '1';

  try {
    const sql = `
      SELECT 
        c.id as chat_id,

        CASE 
          WHEN c.user1_id = ? THEN c.user2_id
          ELSE c.user1_id
        END as other_user_id,

        u.name as other_user_name,
        u.profile_photo_url as other_user_photo,

        (SELECT message FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message,
        (SELECT created_at FROM messages WHERE chat_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message_time,

        CASE
          WHEN c.user1_id = ? THEN COALESCE(c.pinned_by_user1, 0)
          ELSE COALESCE(c.pinned_by_user2, 0)
        END as is_pinned,

        CASE
          WHEN c.user1_id = ? THEN COALESCE(c.archived_by_user1, 0)
          ELSE COALESCE(c.archived_by_user2, 0)
        END as is_archived

      FROM chats c
      JOIN users u ON (
        CASE 
          WHEN c.user1_id = ? THEN c.user2_id
          ELSE c.user1_id
        END = u.id
      )

      WHERE (c.user1_id = ? OR c.user2_id = ?)
        AND (
          (c.user1_id = ? AND COALESCE(c.deleted_by_user1, 0) = 0) OR
          (c.user2_id = ? AND COALESCE(c.deleted_by_user2, 0) = 0)
        )
          AND NOT EXISTS (
  SELECT 1
  FROM user_blocks b
  WHERE (
    b.blocker_id = ?
    AND b.blocked_id = (CASE WHEN c.user1_id = ? THEN c.user2_id ELSE c.user1_id END)
  )
  OR (
    b.blocker_id = (CASE WHEN c.user1_id = ? THEN c.user2_id ELSE c.user1_id END)
    AND b.blocked_id = ?
  )
)



        ${includeArchived ? '' : `
        AND (
          (c.user1_id = ? AND COALESCE(c.archived_by_user1, 0) = 0) OR
          (c.user2_id = ? AND COALESCE(c.archived_by_user2, 0) = 0)
        )`}

      ORDER BY is_pinned DESC, last_message_time DESC
    `;

    const params = [
      userId, // other_user calc
      userId, // is_pinned
      userId, // is_archived
      userId, // join calc
      userId, userId,
      userId, userId,

        // 8-11 NOT EXISTS (4 params)
  userId, // b.blocker_id = ?
  userId, // CASE WHEN c.user1_id = ? (first CASE inside NOT EXISTS)
  userId, // CASE WHEN c.user1_id = ? (second CASE inside NOT EXISTS)
  userId, // b.blocked_id = ?
    ];

    if (!includeArchived) {
      params.push(userId, userId);
    }

    const [chats] = await db.query(sql, params);
    return res.status(200).json(chats);
  } catch (error) {
    console.error("Get Chat List Error:", error);
    return res.status(500).json({ message: "Server error while fetching chat list." });
  }
};

// Soft delete chat (only from user's side)
exports.deleteChat = async (req, res) => {
    const userId = req.user.id;
    const { id: chatId } = req.params;

    try {
        // Verify user is part of this chat
        const [chats] = await db.query(
            "SELECT id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
            [chatId, userId, userId]
        );

        if (chats.length === 0) {
            return res.status(403).json({ message: "You are not a participant in this chat." });
        }

        // Add deleted_by column if it doesn't exist (migration)
        await db.query(`
            ALTER TABLE chats 
            ADD COLUMN IF NOT EXISTS deleted_by_user1 BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS deleted_by_user2 BOOLEAN DEFAULT FALSE
        `).catch(() => {}); // Ignore error if columns already exist

        // Mark chat as deleted for this user
        const [chatDetails] = await db.query(
            "SELECT user1_id, user2_id FROM chats WHERE id = ?",
            [chatId]
        );

        if (chatDetails.length === 0) {
            return res.status(404).json({ message: "Chat not found." });
        }

        const isUser1 = chatDetails[0].user1_id === userId;
        const deleteColumn = isUser1 ? 'deleted_by_user1' : 'deleted_by_user2';

        await db.query(
            `UPDATE chats SET ${deleteColumn} = TRUE WHERE id = ?`,
            [chatId]
        );

        res.status(200).json({ 
            success: true,
            message: "Chat deleted successfully." 
        });

    } catch (error) {
        console.error("Delete Chat Error:", error);
        res.status(500).json({ message: "Server error while deleting chat." });
    }
};

// Soft delete message (only from user's side)
exports.deleteMessage = async (req, res) => {
    const userId = req.user.id;
    const { id: messageId } = req.params;

    try {
        // Verify message belongs to this user
        const [messages] = await db.query(
            "SELECT id, chat_id, sender_id FROM messages WHERE id = ?",
            [messageId]
        );

        if (messages.length === 0) {
            return res.status(404).json({ message: "Message not found." });
        }

        if (messages[0].sender_id !== userId) {
            return res.status(403).json({ message: "You can only delete your own messages." });
        }

        // Add deleted_by_sender column if it doesn't exist
        await ensureMessageColumns();

        // Mark message as deleted
        await db.query(
            "UPDATE messages SET deleted_by_sender = TRUE WHERE id = ?",
            [messageId]
        );

        res.status(200).json({ 
            success: true,
            message: "Message deleted successfully." 
        });

    } catch (error) {
        console.error("Delete Message Error:", error);
        res.status(500).json({ message: "Server error while deleting message." });
    }
};

// Edit message
exports.editMessage = async (req, res) => {
    const userId = req.user.id;
    const { id: messageId } = req.params;
    const { new_message } = req.body;

    if (!new_message || new_message.trim() === '') {
        return res.status(400).json({ message: "Message cannot be empty." });
    }

    try {
        // Verify message ownership
        const [messages] = await db.query(
            "SELECT sender_id FROM messages WHERE id = ?",
            [messageId]
        );

        if (messages.length === 0) return res.status(404).json({ message: "Message not found." });
        if (messages[0].sender_id !== userId) return res.status(403).json({ message: "You can only edit your own messages." });

        // Add is_edited column if not exists
        await ensureMessageColumns();

        await db.query(
            "UPDATE messages SET message = ?, is_edited = TRUE WHERE id = ?",
            [new_message, messageId]
        );

        res.status(200).json({ success: true, message: "Message edited successfully." });
    } catch (error) {
        console.error("Edit Message Error:", error);
        res.status(500).json({ message: "Server error while editing message." });
    }
};

// POST /api/chats/:id/block
exports.blockUser = async (req, res) => {
  const userId = req.user.id;
  const chatId = req.params.id;

  try {
    await ensureBlockAndReportTables();

    // find other user
    const [chats] = await db.query(
      "SELECT user1_id, user2_id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
      [chatId, userId, userId]
    );
    if (!chats.length) return res.status(403).json({ message: "Not allowed" });

    const chat = chats[0];
    const otherUserId = chat.user1_id === userId ? chat.user2_id : chat.user1_id;

    // insert block (ignore duplicates by UNIQUE KEY)
    await db.query(
      "INSERT IGNORE INTO user_blocks (blocker_id, blocked_id) VALUES (?, ?)",
      [userId, otherUserId]
    );

    return res.json({ success: true, blocked_user_id: otherUserId });
  } catch (e) {
    console.error("blockUser error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

// DELETE /api/chats/:id/block
exports.unblockUser = async (req, res) => {
  const userId = req.user.id;
  const chatId = req.params.id;

  try {
    await ensureBlockAndReportTables();

    const [chats] = await db.query(
      "SELECT user1_id, user2_id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
      [chatId, userId, userId]
    );
    if (!chats.length) return res.status(403).json({ message: "Not allowed" });

    const chat = chats[0];
    const otherUserId = chat.user1_id === userId ? chat.user2_id : chat.user1_id;

    await db.query(
      "DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_id = ?",
      [userId, otherUserId]
    );

    return res.json({ success: true, unblocked_user_id: otherUserId });
  } catch (e) {
    console.error("unblockUser error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

// POST /api/chats/:id/report  body: { reason?, details? }
exports.reportUser = async (req, res) => {
  const userId = req.user.id;
  const chatId = req.params.id;
  const { reason, details } = req.body || {};

  try {
    await ensureBlockAndReportTables();

    const [chats] = await db.query(
      "SELECT user1_id, user2_id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
      [chatId, userId, userId]
    );
    if (!chats.length) return res.status(403).json({ message: "Not allowed" });

    const chat = chats[0];
    const otherUserId = chat.user1_id === userId ? chat.user2_id : chat.user1_id;

    await db.query(
      "INSERT INTO user_reports (reporter_id, reported_user_id, chat_id, reason, details) VALUES (?, ?, ?, ?, ?)",
      [userId, otherUserId, chatId, reason || null, details || null]
    );

    return res.json({ success: true });
  } catch (e) {
    console.error("reportUser error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

async function getChatAndRole(db, chatId, userId) {
  const [rows] = await db.query(
    `SELECT id, user1_id, user2_id, deleted_by_user1, deleted_by_user2
     FROM chats
     WHERE id = ? AND (user1_id = ? OR user2_id = ?)`,
    [chatId, userId, userId]
  );

  if (!rows.length) return null;

  const row = rows[0];
  const isUser1 = row.user1_id === userId;

  // if user deleted this chat, disallow actions
  if (isUser1 && row.deleted_by_user1) return null;
  if (!isUser1 && row.deleted_by_user2) return null;

  return { isUser1 };
}


exports.pinChat = async (req, res) => {
  const userId = req.user.id;
  const chatId = req.params.id;
  const { pinned } = req.body; // optional boolean

  try {
    const role = await getChatAndRole(db, chatId, userId);
    if (!role) return res.status(403).json({ message: "Not allowed" });

    const col = role.isUser1 ? "pinned_by_user1" : "pinned_by_user2";

    if (typeof pinned === "boolean") {
      await db.query(`UPDATE chats SET ${col} = ? WHERE id = ?`, [pinned ? 1 : 0, chatId]);
    } else {
      await db.query(`UPDATE chats SET ${col} = IF(${col} = 1, 0, 1) WHERE id = ?`, [chatId]);
    }

    return res.json({ success: true });
  } catch (e) {
    console.error("pinChat error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.archiveChat = async (req, res) => {
  const userId = req.user.id;
  const chatId = req.params.id;
  const { archived } = req.body; // optional boolean

  try {
    const role = await getChatAndRole(db, chatId, userId);
    if (!role) return res.status(403).json({ message: "Not allowed" });

    const col = role.isUser1 ? "archived_by_user1" : "archived_by_user2";

    if (typeof archived === "boolean") {
      await db.query(`UPDATE chats SET ${col} = ? WHERE id = ?`, [archived ? 1 : 0, chatId]);
    } else {
      await db.query(`UPDATE chats SET ${col} = IF(${col} = 1, 0, 1) WHERE id = ?`, [chatId]);
    }

    return res.json({ success: true });
  } catch (e) {
    console.error("archiveChat error:", e);
    return res.status(500).json({ message: "Server error" });
  }
};


// Pin/Unpin message
exports.pinMessage = async (req, res) => {
    const userId = req.user.id;
    const { id: messageId } = req.params;

    try {
        // Verify user is part of the chat
        const [msg] = await db.query("SELECT chat_id FROM messages WHERE id = ?", [messageId]);
        if (msg.length === 0) return res.status(404).json({ message: "Message not found." });
        
        const chatId = msg[0].chat_id;
        
        // Check participation
        const [chats] = await db.query(
            "SELECT id FROM chats WHERE id = ? AND (user1_id = ? OR user2_id = ?)",
            [chatId, userId, userId]
        );
        if (chats.length === 0) return res.status(403).json({ message: "Access denied." });

        // Add is_pinned column
        await ensureMessageColumns();

        // Toggle pin status
        const [current] = await db.query("SELECT is_pinned FROM messages WHERE id = ?", [messageId]);
        const newStatus = !current[0].is_pinned;

        await db.query("UPDATE messages SET is_pinned = ? WHERE id = ?", [newStatus, messageId]);

        res.status(200).json({ 
            success: true, 
            message: newStatus ? "Message pinned." : "Message unpinned.", 
            is_pinned: newStatus 
        });
    } catch (error) {
        console.error("Pin Message Error:", error);
        res.status(500).json({ message: "Server error while pinning message." });
    }
};