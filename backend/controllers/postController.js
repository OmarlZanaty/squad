const db = require('../db');
const notificationController = require('./notificationController'); // Import notification controller

const { processAndUploadImage } = require('../utils/imageProcessor');

const fs = require('fs');
const os = require('os');
const path2 = require('path'); // keep your existing "path" in storage.js, here we avoid conflict
const crypto = require('crypto');
const ffmpeg = require('fluent-ffmpeg');


const BASE_URL = process.env.BASE_URL || 'http://187.124.37.68:3000';

function toAbsoluteUrl(url) {
  if (!url) return null;
  if (url.startsWith('http')) return url;
  return `${BASE_URL}${url}`;
}

const { saveToLocal } = require('../utils/localStorage');

function cleanVideoUrl(url) {
  if (!url) return null;

  // remove any garbage after .mp4
  const match = url.match(/.*\.mp4/);
  return match ? match[0] : url;
}

function isVideoExt(filename = '') {
  const ext = path2.extname(filename).toLowerCase().replace('.', '');
  return [
    'mp4','mov','avi','mkv','webm','m4v',
    'mpg','mpeg','ts','m2ts','mts','3gp','flv','wmv','asf'
  ].includes(ext);
}

function isImageExt(filename = '') {
  const ext = path2.extname(filename).toLowerCase().replace('.', '');
  return ['jpg','jpeg','png','gif','webp','bmp','heic','heif'].includes(ext);
}

function detectMediaType(file) {
  const name = file?.originalname || '';
  const mt = file?.mimetype || '';

  // extension wins (most reliable)
  if (isVideoExt(name)) return 'video';
  if (isImageExt(name)) return 'image';

  // fallback to mimetype
  if (mt.startsWith('video/')) return 'video';
  if (mt.startsWith('image/')) return 'image';

  // unknown → treat as image? or reject
  return null;
}

async function ensureVideoQualityColumns() {
  const columns = [
    ['low_quality_url',    'VARCHAR(500) NULL DEFAULT NULL'],
    ['medium_quality_url', 'VARCHAR(500) NULL DEFAULT NULL'],
    ['high_quality_url',   'VARCHAR(500) NULL DEFAULT NULL'],
    ['thumbnail_url',      'VARCHAR(500) NULL DEFAULT NULL'],
  ];
 
  for (const [col, def] of columns) {
    try {
      await db.query(`ALTER TABLE posts ADD COLUMN IF NOT EXISTS ${col} ${def}`);
    } catch (e) {
      // Column already exists — safe to ignore
      if (!e.message.includes('Duplicate column')) {
        console.warn(`ensureVideoQualityColumns: ${col} — ${e.message}`);
      }
    }
  }
}
exports.sharePost = async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = req.user.id;
    const platform = req.body.platform || 'unknown';

    console.log("SHARE API HIT", { postId, userId, platform });

    await db.query(`
INSERT INTO post_shares (post_id, user_id, platform, share_count)
VALUES (?, ?, ?, 1)
ON DUPLICATE KEY UPDATE share_count = share_count + 1
`, [postId, userId, platform]);

    console.log("SHARE INSERTED");

    res.json({
      success: true,
      message: 'Share recorded'
    });

  } catch (error) {
    console.error('Share post error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to record share'
    });
  }
};

function fixImageMimeIfNeeded(uploadFile, originalname) {
  if (!uploadFile.mimetype || uploadFile.mimetype === 'application/octet-stream') {
    const ext = path2.extname(originalname).toLowerCase();
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.heic': 'image/heic',
      '.heif': 'image/heif',
    };
    uploadFile.mimetype = map[ext] || 'image/jpeg';
  }
}


function tmpFile(ext) {
  const id = crypto.randomBytes(8).toString('hex');
  return path2.join(os.tmpdir(), `squad_${Date.now()}_${id}.${ext}`);
}

// Add this new helper function
// Add this new helper function


/**
 * Transcode a video to MP4, rotating it upright if needed.
 * This helper handles rotation tags, display matrices and heuristics (height > width).
 * It also strips any leftover rotation metadata from the output.
 * @param {string} inputPath  Path to the source video.
 * @returns {Promise<string>} Path to the transcoded MP4.
 */
async function transcodeToMp4(inputPath) {
  return new Promise((resolve, reject) => {
    const out = tmpFile('mp4');
    ffmpeg.ffprobe(inputPath, (err, meta) => {
      if (err) return reject(err);
      let rot = 0, w = 0, h = 0;
      const vs = meta.streams.find(s => s.codec_type === 'video');
      if (vs) {
        w = vs.width; h = vs.height;
        if (vs.tags?.rotate)        rot = parseInt(vs.tags.rotate, 10);
        else if (vs.side_data_list) {
          const dm = vs.side_data_list.find(sd => sd.side_data_type === 'Display Matrix');
          if (dm?.rotation) rot = parseInt(dm.rotation, 10);
        }
        // Removed: if (rot === 0 && h > w) rot = 90; to avoid incorrect heuristic rotations
      }

      let vf = '';
      if (rot === 90 || rot === -270)      vf = 'transpose=1,';             // 90° CW
      else if (rot === -90 || rot === 270) vf = 'transpose=2,';             // 90° CCW
      else if (rot === 180 || rot === -180)vf = 'transpose=2,transpose=2,'; // 180°
      
      ffmpeg(inputPath)
        .outputOptions([
          '-c:v libx264',
          '-crf 23',
          '-preset medium',
          '-movflags +faststart',
          `-vf ${vf}format=yuv420p`,
          '-c:a aac',
          '-b:a 128k',
          '-pix_fmt yuv420p',
          '-metadata:s:v:0 rotate=0',
          '-metadata:s:v:0 displaymatrix='
        ])
        .on('end', () => resolve(out))
        .on('error', reject)
        .save(out);
    });
  });
}


function writeBuffer(filePath, buffer) {
  fs.writeFileSync(filePath, buffer);
}

async function processVideoAsync(postId, mediaUrl, autoApprove) {
  try {
    await new Promise(r => setTimeout(r, 2000));

    await db.query(
      "UPDATE posts SET status = ? WHERE id = ?",
      [autoApprove ? 'active' : 'pending', postId]
    );

  } catch (err) {
    await db.query(
      "UPDATE posts SET status = 'failed' WHERE id = ?",
      [postId]
    );
  }
}



exports.createPost = async (req, res) => {
  console.log('[createPost] Called');
 
  const { caption } = req.body;
  const userId = req.user?.id;
 
  // ── 0. Auth guard ────────────────────────────────────────────────────────
  if (!userId) {
    console.error('[createPost] No user ID in token');
    return res.status(401).json({ success: false, message: 'Not authenticated' });
  }
 
  if (!caption && !req.file) {
    return res.status(400).json({ success: false, message: 'يجب إضافة نص أو صورة أو فيديو.' });
  }
 
  try {
    // ── 1. Auto-approve setting ────────────────────────────────────────────
    let autoApprove = true;
    try {
      const [settings] = await db.query('SELECT auto_approve_posts FROM settings LIMIT 1');
      if (settings.length > 0) autoApprove = !!settings[0].auto_approve_posts;
    } catch (settingsErr) {
      console.warn('[createPost] Settings check failed, defaulting autoApprove=true:', settingsErr.message);
    }
 
    console.log(`[createPost] autoApprove=${autoApprove}`);
 
    // ── 2. No media → text-only post ──────────────────────────────────────
    if (!req.file) {
      const [result] = await db.query(
        'INSERT INTO posts (user_id, media_type, media_url, caption, status) VALUES (?, NULL, NULL, ?, ?)',
        [userId, caption || '', 'pending']
      );
      console.log(`[createPost] Text post created id=${result.insertId}`);
      return res.status(201).json({
        success: true,
        message: 'Post created successfully',
        post: { id: result.insertId, caption: caption || '', media_url: null, media_type: null, status: 'pending' },
      });
    }
 
    // ── 3. Media present ───────────────────────────────────────────────────
    console.log(`[createPost] File received: originalname="${req.file.originalname}" mimetype="${req.file.mimetype}" size=${req.file.size}`);
 
    if (!req.file.buffer || req.file.buffer.length === 0) {
      return res.status(400).json({ success: false, message: 'Uploaded file is empty' });
    }
 
    // ── 3a. Detect media type (extension wins over MIME to handle octet-stream) ──
    const detectedType = detectMediaType(req.file); // your existing function
    if (!detectedType) {
      return res.status(400).json({ success: false, message: 'نوع الملف غير مدعوم' });
    }
    console.log(`[createPost] Detected type: ${detectedType}`);
 
    // ── 4. VIDEO PATH ──────────────────────────────────────────────────────
    if (detectedType === 'video') {
      const path2          = require('path');
      const videoProcessor = require('../utils/videoProcessor');
 
      // 4a. Sanitise filename — strip Arabic/Unicode that causes ffmpeg error 234
      const safeFilename = (typeof videoProcessor.safeName === 'function')
        ? videoProcessor.safeName(req.file.originalname)
        : req.file.originalname
            .replace(/[^\x00-\x7F]/g, '')
            .replace(/[^a-zA-Z0-9\-_.]/g, '_')
            .replace(/_{2,}/g, '_')
            .replace(/^_+|_+$/g, '') || 'video.mp4';
 
      console.log(`[createPost] Safe filename: "${safeFilename}"`);
 
      // 4b. Write to temp dir
      const os   = require('os');
      const fs   = require('fs');
      const tempDir  = path2.join(os.tmpdir(), `upload-${Date.now()}-${Math.random().toString(36).slice(2)}`);
      const tempPath = path2.join(tempDir, safeFilename);
 
      try {
        if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });
        fs.writeFileSync(tempPath, Buffer.from(req.file.buffer));
        console.log(`[createPost] Temp file written: ${tempPath} (${fs.statSync(tempPath).size} bytes)`);
      } catch (writeErr) {
        console.error('[createPost] Failed to write temp file:', writeErr.message);
        return res.status(500).json({ success: false, message: 'Failed to save uploaded file' });
      }
 
      // 4c. Generate thumbnail fast (non-blocking if it fails)
      let thumbnailUrl = null;
      try {
        const thumbnailBuffer = await videoProcessor.generateThumbnail(tempPath);
        const safeBuf = Buffer.isBuffer(thumbnailBuffer) ? thumbnailBuffer : Buffer.from(thumbnailBuffer);
        thumbnailUrl = saveToLocal(safeBuf, `posts/thumbnails/thumb-${Date.now()}.jpg`);
        console.log(`[createPost] Thumbnail: ${thumbnailUrl}`);
      } catch (thumbErr) {
        console.warn('[createPost] Thumbnail generation failed (non-fatal):', thumbErr.message);
      }
 
      // 4d. Insert post row immediately (always pending until video is processed)
      let postId;
      try {
        const [result] = await db.query(
          'INSERT INTO posts (user_id, media_type, thumbnail_url, caption, status) VALUES (?, ?, ?, ?, ?)',
          [userId, 'video', thumbnailUrl, caption || '', 'pending']
        );
        postId = result.insertId;
        console.log(`[createPost] Post row inserted id=${postId}`);
      } catch (dbErr) {
        console.error('[createPost] DB insert failed:', dbErr.message);
        try { require('fs').rmSync(tempDir, { recursive: true, force: true }); } catch (_) {}
        return res.status(500).json({ success: false, message: 'Database error creating post' });
      }
 
      // 4e. Respond immediately — client can now poll for status updates
      res.status(201).json({
        success: true,
        message: 'Post created. Video is processing in background.',
        post: { id: postId, media_type: 'video', thumbnail_url: thumbnailUrl, caption: caption || '', status: 'pending' },
      });
 
      // 4f. Background video processing
          const finalStatus = 'pending'; 
      ;(async () => {
        const fs2 = require('fs');
        try {
          console.log(`[createPost:bg] Starting video processing for post ${postId}`);
 
          const videoData = await videoProcessor.processAndUploadVideo(tempPath, safeFilename, 'posts/media');
 
          if (!videoData) throw new Error('processAndUploadVideo returned null/undefined');
          if (!videoData.qualities) throw new Error('processAndUploadVideo returned no qualities');
 
          const lowUrl    = videoData.qualities?.low?.url    || null;
          const mediumUrl = videoData.qualities?.medium?.url || null;
          const highUrl   = videoData.qualities?.high?.url   || null;
 
          // Require at least one quality URL
          if (!lowUrl && !mediumUrl && !highUrl) {
            throw new Error('All quality processing failed — no output URLs');
          }
 
          let primaryUrl = highUrl || mediumUrl || lowUrl;
          // Strip any garbage after .mp4
          if (primaryUrl && primaryUrl.includes('.mp4')) {
            primaryUrl = primaryUrl.split('.mp4')[0] + '.mp4';
          }
 
          await db.query(
            `UPDATE posts SET media_url=?, low_quality_url=?, medium_quality_url=?, high_quality_url=?, status=? WHERE id=?`,
            [primaryUrl, lowUrl, mediumUrl, highUrl, finalStatus, postId]
          );
 
          console.log(`[createPost:bg] ✅ Post ${postId} processing complete. Status=${finalStatus}`);
 
        } catch (bgErr) {
          console.error(`[createPost:bg] ❌ Post ${postId} processing failed: ${bgErr.message}`);
          try {
            await db.query(`UPDATE posts SET status='failed' WHERE id=?`, [postId]);
          } catch (dbErr2) {
            console.error(`[createPost:bg] Could not update status to failed: ${dbErr2.message}`);
          }
        } finally {
          try {
            fs2.rmSync(tempDir, { recursive: true, force: true });
            console.log(`[createPost:bg] Temp dir cleaned: ${tempDir}`);
          } catch (cleanErr) {
            console.warn(`[createPost:bg] Cleanup failed: ${cleanErr.message}`);
          }
        }
      })();
 
      return; // response already sent above
    }
 
    // ── 5. IMAGE PATH ──────────────────────────────────────────────────────
    if (detectedType === 'image') {
      let uploadFile = {
        buffer: Buffer.from(req.file.buffer),
        originalname: req.file.originalname,
        mimetype: req.file.mimetype,
      };
      fixImageMimeIfNeeded(uploadFile, req.file.originalname); // your existing function
 
      let mediaUrl;
      try {
        mediaUrl = saveToLocal(uploadFile, 'posts/media');
        console.log(`[createPost] Image saved: ${mediaUrl}`);
      } catch (saveErr) {
        console.error('[createPost] saveToLocal failed for image:', saveErr.message);
        return res.status(500).json({ success: false, message: 'Failed to save image' });
      }
 
      const finalStatus = 'pending';
      const [result] = await db.query(
        'INSERT INTO posts (user_id, media_type, media_url, caption, status) VALUES (?, ?, ?, ?, ?)',
        [userId, 'image', mediaUrl, caption || '', finalStatus]
      );
 
      console.log(`[createPost] Image post created id=${result.insertId}`);
      return res.status(201).json({
        success: true,
        message: 'Post created successfully',
        post: { id: result.insertId, media_url: mediaUrl, media_type: 'image', caption: caption || '', status },
      });
    }
 
    // Unreachable but safety net
    return res.status(400).json({ success: false, message: 'Unsupported media type' });
 
  } catch (error) {
    console.error('[createPost] Unhandled error:', error.message, error.stack);
    // Only send response if not already sent (video path sends early)
    if (!res.headersSent) {
      return res.status(500).json({
        success: false,
        error_type: 'CREATE_POST_FAILED',
        message: error.message || 'حدث خطأ أثناء إنشاء المنشور.',
      });
    }
  }
};

exports.getPosts = async (req, res) => {
  const page = parseInt(req.query.page, 10) || 1;
  const limit = Math.min(parseInt(req.query.limit, 10) || 10, 50);
  const offset = (page - 1) * limit;

  const filterUserId = req.query.user_id;
  const lastCreatedAt = req.query.lastCreatedAt || null;
  const { country, position } = req.query;
  const userId = req.user ? req.user.id : null;

  try {
    let sql = `
      SELECT
        p.id, p.user_id, p.media_type, p.media_url, p.thumbnail_url,
        p.low_quality_url, p.medium_quality_url, p.high_quality_url,
        p.caption, p.created_at, p.status, p.views, p.is_pinned,
        u.name as author_name, u.profile_photo_url as author_photo,
        COALESCE(pl.country, '') as country,
        COALESCE(pl.position, '') as position,
        u.type as author_type,
        COALESCE(pl.current_club, '') as current_club,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'like' THEN 1 ELSE 0 END), 0) as like_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'love' THEN 1 ELSE 0 END), 0) as love_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'talent' THEN 1 ELSE 0 END), 0) as talent_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'amazing' THEN 1 ELSE 0 END), 0) as amazing_count,
        (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comment_count,
        (SELECT reaction_type FROM reactions WHERE post_id = p.id AND user_id = ? LIMIT 1) AS user_reaction,
        (SELECT COUNT(*) FROM hidden_posts WHERE post_id = p.id AND user_id = ?) as is_hidden_by_me
      FROM posts p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN players pl ON u.id = pl.user_id
      LEFT JOIN reactions r ON p.id = r.post_id
      WHERE p.status = 'active'
    `;

    const params = [userId || 0, userId || 0];

    if (filterUserId) {
      sql += ` AND p.user_id = ?`;
      params.push(filterUserId);
    }
    if (country) {
      sql += ` AND COALESCE(pl.country, '') = ?`;
      params.push(country);
    }
    if (position) {
      sql += ` AND COALESCE(pl.position, '') = ?`;
      params.push(position);
    }
    if (lastCreatedAt) {
      sql += ` AND p.created_at < ?`;
      params.push(lastCreatedAt);
    }

    sql += `
      GROUP BY p.id, p.user_id, p.media_type, p.media_url, p.thumbnail_url,
               p.low_quality_url, p.medium_quality_url, p.high_quality_url,
               p.caption, p.created_at, p.status, p.views, p.is_pinned,
               u.name, u.profile_photo_url, pl.country, pl.position, u.type, pl.current_club
      ORDER BY p.created_at DESC
      LIMIT ? OFFSET ?
    `;
    params.push(limit, offset);

    const [posts] = await db.query(sql, params);

    const mapped = posts.map(p => ({
      ...p,
      media_url:          cleanVideoUrl(toAbsoluteUrl(p.media_url)),
      thumbnail_url:      toAbsoluteUrl(p.thumbnail_url),
      author_photo:       toAbsoluteUrl(p.author_photo),
      low_quality_url:    toAbsoluteUrl(p.low_quality_url),    // ✅
      medium_quality_url: toAbsoluteUrl(p.medium_quality_url), // ✅
      high_quality_url:   toAbsoluteUrl(p.high_quality_url),   // ✅
    }));

    res.status(200).json(mapped);

  } catch (error) {
    console.error("Get Posts Error:", error);
    res.status(500).json({ message: 'Server error while fetching posts.' });
  }
};

exports.getPostById = async (req, res) => {
  const { id } = req.params;
  const userId = req.user ? req.user.id : null;

  try {
    const sql = `
      SELECT
        p.id, p.user_id, p.media_type, p.media_url, p.thumbnail_url,
        p.low_quality_url, p.medium_quality_url, p.high_quality_url,
        p.caption, p.created_at, p.status, p.views, p.is_pinned,
        u.name as author_name, u.profile_photo_url as author_photo,
        COALESCE(pl.country, '') as country,
        COALESCE(pl.position, '') as position,
        u.type,
        COALESCE(pl.current_club, '') as current_club,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'like' THEN 1 ELSE 0 END), 0) AS like_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'love' THEN 1 ELSE 0 END), 0) AS love_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'talent' THEN 1 ELSE 0 END), 0) AS talent_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'amazing' THEN 1 ELSE 0 END), 0) AS amazing_count,
        (SELECT COUNT(*) FROM comments WHERE post_id = p.id) as comment_count,
        (SELECT reaction_type FROM reactions WHERE post_id = p.id AND user_id = ? LIMIT 1) AS user_reaction,
        (SELECT COUNT(*) FROM hidden_posts WHERE post_id = p.id AND user_id = ?) as is_hidden_by_me
      FROM posts p
      JOIN users u ON p.user_id = u.id
      LEFT JOIN players pl ON u.id = pl.user_id
      LEFT JOIN reactions r ON p.id = r.post_id
      WHERE p.id = ?
      GROUP BY p.id, p.user_id, p.media_type, p.media_url, p.thumbnail_url,
               p.low_quality_url, p.medium_quality_url, p.high_quality_url,
               p.caption, p.created_at, p.status, p.views, p.is_pinned,
               u.name, u.profile_photo_url, pl.country, pl.position, u.type, pl.current_club
    `;

    const [posts] = await db.query(sql, [userId || 0, userId || 0, id]);

    if (posts.length === 0) {
      return res.status(404).json({ message: 'Post not found.' });
    }

    const post = posts[0];

    res.status(200).json({
      ...post,
      media_url:          cleanVideoUrl(toAbsoluteUrl(post.media_url)),
      thumbnail_url:      toAbsoluteUrl(post.thumbnail_url),
      author_photo:       toAbsoluteUrl(post.author_photo),
      low_quality_url:    toAbsoluteUrl(post.low_quality_url),    // ✅
      medium_quality_url: toAbsoluteUrl(post.medium_quality_url), // ✅
      high_quality_url:   toAbsoluteUrl(post.high_quality_url),   // ✅
    });

  } catch (error) {
    console.error("Get Post By ID Error:", error);
    res.status(500).json({ message: 'Server error while fetching post.' });
  }
};

exports.reactToPost = async (req, res) => {
    const userId = req.user.id;
    const { id: postId } = req.params;
    const { reaction_type } = req.body;

    console.log('Reaction API called - User:', userId, 'Post:', postId, 'Reaction:', reaction_type);

    const validReactions = ['like', 'love', 'talent', 'amazing'];
    if (!reaction_type || !validReactions.includes(reaction_type)) {
        console.log('Invalid reaction type:', reaction_type);
        return res.status(400).json({ message: "Invalid reaction type." });
    }

    try {
        // Check if the user has already reacted to this post
        const [existingReactions] = await db.query("SELECT * FROM reactions WHERE post_id = ? AND user_id = ?", [postId, userId]);

        if (existingReactions.length > 0) {
            // User has already reacted
            if (existingReactions[0].reaction_type === reaction_type) {
                // User is un-reacting
                await db.query("DELETE FROM reactions WHERE post_id = ? AND user_id = ?", [postId, userId]);
                res.status(200).json({ message: `Un-reacted to post ${postId}.` });
            } else {
                // User is changing their reaction
                await db.query("UPDATE reactions SET reaction_type = ? WHERE post_id = ? AND user_id = ?", [reaction_type, postId, userId]);
                res.status(200).json({ message: `Changed reaction on post ${postId} to ${reaction_type}.` });
            }
        } else {
            // User is reacting for the first time
            await db.query("INSERT INTO reactions (post_id, user_id, reaction_type) VALUES (?, ?, ?)", [postId, userId, reaction_type]);
            res.status(201).json({ message: `Reacted to post ${postId} with ${reaction_type}.` });

            // --- NOTIFICATION LOGIC ---
            try {
                // Get post owner
                const [posts] = await db.query("SELECT user_id FROM posts WHERE id = ?", [postId]);
                if (posts.length > 0) {
                    const postOwnerId = posts[0].user_id;
                    
                    // Don't notify if user reacts to their own post
                    if (postOwnerId !== userId) {
                        // Create notification using new signature: (userId, actorId, type, postId)
                        await notificationController.createNotification(postOwnerId, userId, reaction_type, postId);
                    }
                }
            } catch (notifError) {
                console.error("Notification Error (Non-fatal):", notifError);
            }
            // --------------------------
        }
    } catch (error) {
        console.error("Reaction Error:", error);
        res.status(500).json({ message: "Server error while reacting to post." });
    }
};

exports.deletePost = async (req, res) => {
    const userId = req.user.id;
    const { id: postId } = req.params;

    try {
        const [posts] = await db.query("SELECT user_id FROM posts WHERE id = ?", [postId]);

        if (posts.length === 0) {
            return res.status(404).json({ message: 'Post not found.' });
        }

        if (posts[0].user_id !== userId) {
            return res.status(403).json({ message: 'You can only delete your own posts.' });
        }

        await db.query("DELETE FROM reactions WHERE post_id = ?", [postId]);
        await db.query("DELETE FROM comments WHERE post_id = ?", [postId]);
        await db.query("DELETE FROM posts WHERE id = ?", [postId]);

        res.status(200).json({ message: 'Post deleted successfully.' });
    } catch (error) {
        console.error("Delete Post Error:", error);
        res.status(500).json({ message: 'Server error while deleting post.' });
    }
};

exports.updatePost = async (req, res) => {
    const postId = req.params.id;
    const userId = req.user.id;
    const { caption, remove_media } = req.body;

    try {
        const [posts] = await db.query('SELECT * FROM posts WHERE id = ? AND user_id = ?', [postId, userId]);

        if (posts.length === 0) {
            return res.status(404).json({ message: 'Post not found or you do not have permission to edit it' });
        }

        let post = posts[0];
        let { media_url: mediaUrl, media_type: mediaType } = post;

        if (remove_media === 'true') {
            mediaUrl = null;
            mediaType = null;
        } else if (req.file) {
  console.log('Updating post with new media:', req.file.originalname, req.file.mimetype);

  let uploadFile = {
    buffer: req.file.buffer,
    originalname: req.file.originalname,
    mimetype: req.file.mimetype,
  };

  	const isVideo = isVideoExt(req.file.originalname) || (req.file.mimetype || '').startsWith('video/');
	//const isAlreadyMp4 = (req.file.mimetype === 'video/mp4') || req.file.originalname.toLowerCase().endsWith('.mp4');

	const { getVideoMetadata } = require('../utils/videoProcessor'); // wherever getVideoMetadata lives

if (isVideo) {
  const tempPath = tmpFile(path2.extname(req.file.originalname).replace('.', '') || 'bin');
  writeBuffer(tempPath, req.file.buffer);
  const meta = await getVideoMetadata(tempPath);
  const needsRotation = (meta.rotation !== 0) || (meta.height > meta.width);

  if (needsRotation) {
    const fixedPath  = await transcodeToMp4(tempPath);
    const fixedBuf   = fs.readFileSync(fixedPath);
    uploadFile       = {
      buffer: fixedBuf,
      originalname: req.file.originalname.replace(/\.[^/.]+$/, '') + '.mp4',
      mimetype: 'video/mp4'
    };
    mediaType = 'video';
    fs.unlinkSync(fixedPath);
  } else {
    uploadFile = { buffer: req.file.buffer, originalname: req.file.originalname, mimetype: req.file.mimetype };
  }
  fs.unlinkSync(tempPath);
}
  else { 
  const t = detectMediaType(req.file);
  if (!t) {
    return res.status(400).json({ message: 'Unsupported media type' });
  }
  mediaType = t;

  if (mediaType === 'image') {
    fixImageMimeIfNeeded(uploadFile, req.file.originalname);
  }
}


  const { saveToLocal } = require('../utils/localStorage');

  mediaUrl = saveToLocal(uploadFile, 'posts/media');
}


        await db.query('UPDATE posts SET caption = ?, media_url = ?, media_type = ? WHERE id = ?', [caption || '', mediaUrl, mediaType, postId]);

        res.json({
            success: true,
            message: 'Post updated successfully',
            post: {
                id: postId,
                caption: caption || '',
                media_url: mediaUrl,
                media_type: mediaType
            }
        });
    } catch (error) {
        console.error('Error updating post:', error);
        res.status(500).json({ message: 'Server error while updating post.', error: error.message });
    }
};

exports.incrementView = async (req, res) => {
    const { id } = req.params;
    try {
        await db.query("UPDATE posts SET views = views + 1 WHERE id = ?", [id]);
        res.status(200).json({ success: true, message: 'View count incremented' });
    } catch (error) {
        console.error("Increment View Error:", error);
        res.status(500).json({ message: 'Server error while incrementing view.' });
    }
};

// Pin/Unpin a post
exports.togglePin = async (req, res) => {
    try {
        const postId = req.params.id;
        const userId = req.user.id;

        // Check if post belongs to user
        const [posts] = await db.query('SELECT is_pinned FROM posts WHERE id = ? AND user_id = ?', [postId, userId]);
        
        if (posts.length === 0) {
            return res.status(403).json({ message: 'Not authorized or post not found' });
        }

        const newStatus = !posts[0].is_pinned;
        await db.query('UPDATE posts SET is_pinned = ? WHERE id = ?', [newStatus, postId]);

        res.json({ message: newStatus ? 'Post pinned' : 'Post unpinned', is_pinned: newStatus });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.ensureVideoQualityColumns = ensureVideoQualityColumns;
// Hide/Unhide a post (User specific)
// We need a separate table for hidden posts: hidden_posts (user_id, post_id)
exports.toggleHide = async (req, res) => {
    try {
        const postId = req.params.id;
        const userId = req.user.id;

        // Check if already hidden
        const [existing] = await db.query('SELECT * FROM hidden_posts WHERE user_id = ? AND post_id = ?', [userId, postId]);

        let isHidden = false;
        if (existing.length > 0) {
            // Unhide
            await db.query('DELETE FROM hidden_posts WHERE user_id = ? AND post_id = ?', [userId, postId]);
            isHidden = false;
        } else {
            // Hide
            await db.query('INSERT INTO hidden_posts (user_id, post_id) VALUES (?, ?)', [userId, postId]);
            isHidden = true;
        }

        res.json({ message: isHidden ? 'Post hidden' : 'Post visible', is_hidden: isHidden });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

