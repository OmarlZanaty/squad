const db = require('../db');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { calculateRating } = require('./calculateRating');

exports.followUser = async (req, res) => {
    const followerId = req.user.id;
    const followingId = req.params.id;

    if (followerId == followingId) {
        return res.status(400).json({ message: "You cannot follow yourself." });
    }

    try {
        const [existingFollow] = await db.query("SELECT * FROM follows WHERE follower_id = ? AND following_id = ?", [followerId, followingId]);

        if (existingFollow.length > 0) {
            return res.status(400).json({ message: "You are already following this user." });
        }

        await db.query("INSERT INTO follows (follower_id, following_id) VALUES (?, ?)", [followerId, followingId]);
        res.status(200).json({ message: "Followed successfully." });
    } catch (error) {
        console.error("Follow User Error:", error);
        res.status(500).json({ message: "Server error while following user." });
    }
};

exports.unfollowUser = async (req, res) => {
    const followerId = req.user.id;
    const followingId = req.params.id;

    try {
        await db.query("DELETE FROM follows WHERE follower_id = ? AND following_id = ?", [followerId, followingId]);
        res.status(200).json({ message: "Unfollowed successfully." });
    } catch (error) {
        console.error("Unfollow User Error:", error);
        res.status(500).json({ message: "Server error while unfollowing user." });
    }
};

exports.getFollowers = async (req, res) => {
    const userId = req.params.id;

    try {
        const sql = `
            SELECT u.id, u.name, u.profile_photo_url, 
                   COALESCE(p.position, '') as position, 
                   COALESCE(p.country, '') as country, 
                   COALESCE(p.current_club, '') as current_club, 
                   u.type, u.status
            FROM follows f
            JOIN users u ON f.follower_id = u.id
            LEFT JOIN players p ON u.id = p.user_id
            WHERE f.following_id = ?
  		AND (u.type != 'player' OR u.status = 'active')

        `;
        const [followers] = await db.query(sql, [userId]);
        res.status(200).json(followers);
    } catch (error) {
        console.error("Get Followers Error:", error);
        res.status(500).json({ message: "Server error while fetching followers." });
    }
};

exports.getFollowing = async (req, res) => {
  const userId = req.params.id;

  try {
    const sql = `
      SELECT u.id, u.name, u.profile_photo_url, 
             COALESCE(p.position, '') as position, 
             COALESCE(p.country, '') as country, 
             COALESCE(p.current_club, '') as current_club, 
             u.type, u.status
      FROM follows f
      JOIN users u ON f.following_id = u.id
      LEFT JOIN players p ON u.id = p.user_id
      WHERE f.follower_id = ?
        AND (u.type != 'player' OR u.status = 'active')
    `;
    const [following] = await db.query(sql, [userId]);
    res.status(200).json(following);
  } catch (error) {
    console.error("Get Following Error:", error);
    res.status(500).json({ message: "Server error while fetching following." });
  }
};

exports.trackProfileView = async (req, res) => {
  const viewerId = req.user ? req.user.id : null;
  const viewedUserId = parseInt(req.params.id, 10);

  if (!viewerId) {
    return res.status(401).json({ message: "Unauthorized." });
  }

  if (!viewedUserId) {
    return res.status(400).json({ message: "Invalid user id." });
  }

  if (viewerId === viewedUserId) {
    return res.status(200).json({ message: "Ignored self view." });
  }

  try {

    // check if view already exists
    const [existing] = await db.query(
      "SELECT id FROM profile_views WHERE viewer_id = ? AND viewed_user_id = ?",
      [viewerId, viewedUserId]
    );

    if (existing.length === 0) {

      // insert view record
      await db.query(
        "INSERT INTO profile_views (viewer_id, viewed_user_id) VALUES (?, ?)",
        [viewerId, viewedUserId]
      );

      // increment counter
      await db.query(
        "UPDATE users SET profile_views_count = COALESCE(profile_views_count,0) + 1 WHERE id = ?",
        [viewedUserId]
      );

      console.log(`Profile view counted: ${viewerId} -> ${viewedUserId}`);
    } else {
      console.log(`Profile view already counted: ${viewerId} -> ${viewedUserId}`);
    }

    res.status(200).json({ message: "View tracked." });

  } catch (error) {
    console.error("Track Profile View Error:", error);
    res.status(500).json({ message: "Server error while tracking view." });
  }
};

exports.getMostViewedPlayers = async (req, res) => {
  const currentUserId = req.user ? req.user.id : 0;
  const limit = Math.min(parseInt(req.query.limit || "10", 10), 50);

  try {
    const sql = `
      SELECT 
        u.id, u.name, u.type,
        COALESCE(p.country, '') as country,
        COALESCE(p.position, '') as position,
        u.profile_photo_url,
        COALESCE(p.current_club, '') as current_club,
        u.created_at, p.height, p.weight, p.age, u.status,
        u.profile_views_count,
        (SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS post_count,
        (SELECT COUNT(*) FROM follows WHERE following_id = u.id) AS follower_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = u.id) > 0 AS is_following
      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.type = 'player'
        AND u.status = 'active'
        AND u.profile_views_count > 0
        AND u.id != ?
      ORDER BY u.profile_views_count DESC
      LIMIT ?
    `;

    const [rows] = await db.query(sql, [currentUserId, currentUserId, limit]);

    const results = rows.map(u => ({
      ...u,
      height: u.height != null ? parseInt(u.height) : null,
      weight: u.weight != null ? parseInt(u.weight) : null,
      age: u.age != null ? parseInt(u.age) : null,
      profile_views_count: parseInt(u.profile_views_count || 0),
      post_count: parseInt(u.post_count || 0),
      follower_count: parseInt(u.follower_count || 0),
      following_count: parseInt(u.following_count || 0),
      is_following: !!u.is_following,
    }));

    res.status(200).json(results);
  } catch (error) {
    console.error("Get Most Viewed Players Error:", error);
    res.status(500).json({ message: "Server error while fetching most viewed players." });
  }
};


exports.getUserProfile = async (req, res) => {
  const requestedId = parseInt(req.params.id, 10);
  const currentUserIdRaw = req.user?.id ?? null;
  const currentUserId = currentUserIdRaw != null ? Number(currentUserIdRaw) : null;

  console.log(
    `getUserProfile called for user ${requestedId} - v17 (share_count fix)`,
    { currentUserId, requestedId }
  );

  if (!Number.isFinite(requestedId)) {
    return res.status(400).json({ message: "Invalid user id." });
  }

  try {
    // Extract date range from query parameters
    const startDate = req.query.startDate ? new Date(req.query.startDate) : null;
    const endDate = req.query.endDate ? new Date(req.query.endDate) : null;

    let dateFilter = '';
    let dateParams = [];

    if (startDate && endDate) {
      dateFilter = ' AND p.created_at BETWEEN ? AND ?';
      dateParams.push(startDate.toISOString().slice(0, 19).replace('T', ' '));
      dateParams.push(endDate.toISOString().slice(0, 19).replace('T', ' '));
    } else if (startDate) {
      dateFilter = ' AND p.created_at >= ?';
      dateParams.push(startDate.toISOString().slice(0, 19).replace('T', ' '));
    } else if (endDate) {
      dateFilter = ' AND p.created_at <= ?';
      dateParams.push(endDate.toISOString().slice(0, 19).replace('T', ' '));
    }

    const sql = `
      SELECT 
        u.id, u.name, u.email, u.phone, u.phone_verified, u.type,
        COALESCE(p.country, '') AS country,
        COALESCE(p.position, '') AS position,
        u.profile_photo_url, u.cover_photo_url,
        u.cover_focus_x, u.cover_focus_y, u.profile_focus_x, u.profile_focus_y,
        COALESCE(p.bio,'') AS bio,
        p.height, p.age, p.weight,
        COALESCE(p.current_club,'') AS current_club,
        u.created_at,
        
(
    SELECT COUNT(*) 
    FROM profile_views pv 
    WHERE pv.viewed_user_id = u.id
    ${dateFilter.replace(/p.created_at/g, 'pv.viewed_at')}
  ) AS profile_views_count,
        (SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS post_count,
        (SELECT COUNT(*) FROM follows WHERE following_id = u.id) AS follower_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = u.id) > 0 AS is_following,

        /* TOTAL POST VIEWS */
        (SELECT COALESCE(SUM(COALESCE(p2.views,0)),0) FROM posts p2 WHERE p2.user_id = u.id ${dateFilter.replace(/p.created_at/g, 'p2.created_at')}) AS total_views,

        /* TOTAL COMMENTS */
        (SELECT COALESCE(COUNT(*),0) FROM comments c JOIN posts p3 ON p3.id = c.post_id WHERE p3.user_id = u.id ${dateFilter.replace(/p.created_at/g, 'p3.created_at')}) AS total_comments,

        /* TOTAL LIKES */
        (SELECT COALESCE(COUNT(*),0) FROM reactions r JOIN posts p4 ON p4.id = r.post_id WHERE p4.user_id = u.id AND r.reaction_type = 'like' ${dateFilter.replace(/p.created_at/g, 'p4.created_at')}) AS total_likes,

        /* TOTAL SHARES */
        ((SELECT COALESCE(SUM(ps.share_count),0) FROM post_shares ps JOIN posts p5 ON p5.id = ps.post_id WHERE p5.user_id = u.id ${dateFilter.replace(/p.created_at/g, 'p5.created_at')})
        +
        (SELECT COUNT(*) FROM profile_shares prs WHERE prs.profile_user_id = u.id ${dateFilter.replace(/p.created_at/g, 'prs.created_at')})) AS total_shares

      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.id = ?
    `;

    const [users] = await db.query(sql, [
      currentUserId || 0,
      ...dateParams, ...dateParams, ...dateParams, ...dateParams, ...dateParams, ...dateParams,
      requestedId
    ]);


    if (!users || users.length === 0) {
      return res.status(404).json({ message: "User not found." });
    }

        const user = users[0];

    const ratingStats = {
      posts: parseInt(user.post_count || 0),
      followers: parseInt(user.follower_count || 0),
      following: parseInt(user.following_count || 0),
      totalReactions: parseInt(user.total_likes || 0),
      comments: parseInt(user.total_comments || 0),
      shares: parseInt(user.total_shares || 0),
      views: parseInt(user.total_views || 0) + parseInt(user.profile_views_count || 0),
    };

    const formattedUser = {
  ...user,
  post_count: parseInt(user.post_count || 0),
  follower_count: parseInt(user.follower_count || 0),
  following_count: parseInt(user.following_count || 0),
  is_following: !!user.is_following,
  height: user.height != null ? parseInt(user.height) : null,
  age: user.age != null ? parseInt(user.age) : null,
  weight: user.weight != null ? parseInt(user.weight) : null,
  current_club: user.current_club || null,
  rating: calculateRating(ratingStats),

  /* ✅ FIXED HERE */
  total_views: 
    parseInt(user.total_views || 0) + 
    parseInt(user.profile_views_count || 0),

  total_likes: parseInt(user.total_likes || 0),
  total_comments: parseInt(user.total_comments || 0),
  total_shares: parseInt(user.total_shares || 0),

  profile_views: parseInt(user.profile_views_count || 0),

  phone: user.phone ? String(user.phone) : null,
  phone_verified: user.phone_verified === 1 || user.phone_verified === true,
};


    const isSelf = currentUserId !== null && currentUserId === requestedId;

    if (!isSelf) {
      delete formattedUser.email;
      delete formattedUser.phone;
      delete formattedUser.phone_verified;
    }

    return res.status(200).json(formattedUser);

  } catch (error) {
    console.error("Get User Profile Error:", error);

    return res.status(500).json({
      message: "Server error while fetching user profile.",
      error: error.message,
    });
  }
};

exports.getMostActivePlayers = async (req, res) => {
  const currentUserId = req.user ? req.user.id : 0;
  const limit = Math.min(parseInt(req.query.limit || "10", 10), 50);

  try {
    const sql = `
      SELECT 
        u.id, u.name, u.type,
        COALESCE(p.country, '') as country,
        COALESCE(p.position, '') as position,
        u.profile_photo_url,
        COALESCE(p.current_club, '') as current_club,
        u.created_at, p.height, p.weight, p.age, u.status,

        /* TOTAL LIKES */
        (SELECT COUNT(*) 
         FROM reactions r 
         JOIN posts p1 ON p1.id = r.post_id 
         WHERE p1.user_id = u.id AND r.reaction_type = 'like') AS total_likes,

        /* TOTAL COMMENTS */
        (SELECT COUNT(*) 
         FROM comments c 
         JOIN posts p2 ON p2.id = c.post_id 
         WHERE p2.user_id = u.id) AS total_comments,

        /* TOTAL SHARES */
        (
          (SELECT COALESCE(SUM(ps.share_count),0) 
           FROM post_shares ps 
           JOIN posts p3 ON p3.id = ps.post_id 
           WHERE p3.user_id = u.id)
          +
          (SELECT COUNT(*) 
           FROM profile_shares prs 
           WHERE prs.profile_user_id = u.id)
        ) AS total_shares,

        /* SCORE */
        (
          (SELECT COUNT(*) FROM reactions r JOIN posts p1 ON p1.id = r.post_id WHERE p1.user_id = u.id AND r.reaction_type = 'like')
          +
          (SELECT COUNT(*) FROM comments c JOIN posts p2 ON p2.id = c.post_id WHERE p2.user_id = u.id)
          +
          (
            (SELECT COALESCE(SUM(ps.share_count),0) FROM post_shares ps JOIN posts p3 ON p3.id = ps.post_id WHERE p3.user_id = u.id)
            +
            (SELECT COUNT(*) FROM profile_shares prs WHERE prs.profile_user_id = u.id)
          )
        ) AS total_score

      FROM users u
      LEFT JOIN players p ON u.id = p.user_id
      WHERE u.type = 'player'
        AND u.status = 'active'
        AND u.id != ?
      ORDER BY total_score DESC
      LIMIT ?
    `;

    const [rows] = await db.query(sql, [currentUserId, limit]);

    const results = rows.map(u => ({
      ...u,
      total_likes: parseInt(u.total_likes || 0),
      total_comments: parseInt(u.total_comments || 0),
      total_shares: parseInt(u.total_shares || 0),
      total_score: parseInt(u.total_score || 0),
    }));

    res.status(200).json(results);

  } catch (error) {
    console.error("Get Most Active Players Error:", error);
    res.status(500).json({ message: "Server error while fetching most active players." });
  }
};

exports.searchUsers = async (req, res) => {
    const { q } = req.query;
    const currentUserId = req.user ? req.user.id : null;

    if (!q || q.trim().length === 0) {
        return res.status(400).json({ message: 'Search query is required.' });
    }

    try {
        const searchTerm = `%${q.trim()}%`;
        
const sql = `
  SELECT 
      u.id,
      u.name,
      u.email,
      u.type,
      COALESCE(p.country, '') AS country,
      COALESCE(p.position, '') AS position,
      u.profile_photo_url,
      COALESCE(p.current_club, '') AS current_club,
      u.created_at,
      p.height,
      p.weight,
      p.age,
      u.status,
      (SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS post_count,
      (SELECT COUNT(*) FROM follows WHERE following_id = u.id) AS follower_count,
      (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count,
      (SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = u.id) > 0 AS is_following
  FROM users u
  LEFT JOIN players p ON u.id = p.user_id
  WHERE (
      LOWER(u.name) LIKE LOWER(?)
      OR LOWER(COALESCE(p.position,  '')) LIKE LOWER(?)
      OR LOWER(COALESCE(p.current_club, '')) LIKE LOWER(?)
      OR LOWER(COALESCE(p.country,      '')) LIKE LOWER(?)
  )
    AND (u.type != 'player' OR u.status = 'active')
  ORDER BY
      is_following DESC,
      CASE u.type
          WHEN 'player' THEN 1
          WHEN 'scout'  THEN 2
          WHEN 'guest'  THEN 3
          ELSE 4
      END,
      u.name ASC
  LIMIT 50
`;

const [users] = await db.query(sql, [currentUserId || 0, searchTerm, searchTerm, searchTerm, searchTerm]);

        const results = users.map(user => {
  	const { email, ...u } = user;
  	return {
    	...u,
    	height: u.height != null ? parseInt(u.height) : null,
    	weight: u.weight != null ? parseInt(u.weight) : null,
    	age: u.age != null ? parseInt(u.age) : null,
    	post_count: parseInt(u.post_count || 0),
    	follower_count: parseInt(u.follower_count || 0),
    	following_count: parseInt(u.following_count || 0),
    	is_following: !!u.is_following,
  		};
	});


        res.status(200).json(results);
    } catch (error) {
        console.error("Search Users Error:", error);
        res.status(500).json({ message: "Server error while searching users." });
    }
};

exports.getPlayers = async (req, res) => {
  const currentUserId = req.user ? req.user.id : 0;

  const sort = (req.query.sort || 'new').toLowerCase(); 
  const limit = parseInt(req.query.limit || '50', 10);
  const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

  try {
    // We'll use a derived table for follower_count so we can filter by it.
    let orderBy = 'u.is_vip DESC, u.created_at DESC';
    let extraWhere = '';

    if (sort === 'followers') {
      orderBy = 'fc.follower_count DESC';
      extraWhere = ' AND fc.follower_count > 0 ';
    }

    if (sort === 'most_viewed') {
      orderBy = 'u.profile_views_count DESC';
      extraWhere = ' AND u.profile_views_count > 0 ';
    }

    if (sort === 'name') orderBy = 'u.name ASC';

    const sql = `
      SELECT 
        u.id, u.name, u.type, 
        COALESCE(p.country, '') as country, 
        COALESCE(p.position, '') as position,
        u.profile_photo_url, 
        COALESCE(p.current_club, '') as current_club, 
        u.created_at, p.height, p.weight, p.age, u.status,
        u.profile_views_count,u.is_vip,

        COALESCE(fc.follower_count, 0) AS follower_count,
        (SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS post_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = u.id) AS following_count,
        (SELECT COUNT(*) FROM follows WHERE follower_id = ? AND following_id = u.id) > 0 AS is_following

      FROM users u
      LEFT JOIN players p ON u.id = p.user_id

      LEFT JOIN (
        SELECT following_id, COUNT(*) AS follower_count
        FROM follows
        GROUP BY following_id
      ) fc ON fc.following_id = u.id

      WHERE u.type = 'player'
        AND u.status = 'active'
        AND u.id != ?
        ${extraWhere}

      ORDER BY ${orderBy}
      LIMIT ? OFFSET ?
    `;

    const [users] = await db.query(sql, [currentUserId, currentUserId, limit, offset]);

    const results = users.map(u => ({
      ...u,
      height: u.height != null ? parseInt(u.height) : null,
      weight: u.weight != null ? parseInt(u.weight) : null,
      age: u.age != null ? parseInt(u.age) : null,
      profile_views_count: parseInt(u.profile_views_count || 0),
      post_count: parseInt(u.post_count || 0),
      follower_count: parseInt(u.follower_count || 0),
      following_count: parseInt(u.following_count || 0),
      is_following: !!u.is_following,
        // ✅ ADD THIS
      is_vip: u.is_vip === 1 || u.is_vip === true,
    }));

    res.status(200).json(results);
  } catch (error) {
    console.error("Get Players Error:", error);
    res.status(500).json({ message: "Server error while fetching players." });
  }
};



exports.getUserPosts = async (req, res) => {
  const { id: userId } = req.params;
  const viewerId = req.user ? req.user.id : null;
 
  try {
    const sql = `
      SELECT
        p.id,
        p.user_id,
        p.media_type,
        p.media_url,
        p.thumbnail_url,
        p.low_quality_url,
        p.medium_quality_url,
        p.high_quality_url,
        p.caption,
        p.created_at,
        p.status,
        p.views,
        p.is_pinned,
        u.name          AS author_name,
        u.profile_photo_url AS author_photo,
        COALESCE(pl.country,      '') AS country,
        COALESCE(pl.position,     '') AS position,
        u.type                        AS author_type,
        COALESCE(pl.current_club, '') AS current_club,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'like'    THEN 1 ELSE 0 END), 0) AS like_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'love'    THEN 1 ELSE 0 END), 0) AS love_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'talent'  THEN 1 ELSE 0 END), 0) AS talent_count,
        COALESCE(SUM(CASE WHEN r.reaction_type = 'amazing' THEN 1 ELSE 0 END), 0) AS amazing_count,
        (SELECT COUNT(*) FROM comments    WHERE post_id = p.id)                         AS comment_count,
        (SELECT reaction_type FROM reactions WHERE post_id = p.id AND user_id = ? LIMIT 1) AS user_reaction
      FROM posts p
      JOIN  users   u  ON p.user_id = u.id
      LEFT JOIN players pl ON u.id   = pl.user_id
      LEFT JOIN reactions r ON p.id  = r.post_id
      WHERE p.user_id = ?
        AND p.status IN ('active', 'pending')
      GROUP BY
        p.id, p.user_id, p.media_type, p.media_url, p.thumbnail_url,
        p.low_quality_url, p.medium_quality_url, p.high_quality_url,
        p.caption, p.created_at, p.status, p.views, p.is_pinned,
        u.name, u.profile_photo_url, pl.country, pl.position, u.type, pl.current_club
      ORDER BY p.is_pinned DESC, p.created_at DESC
    `;
 
    const [posts] = await db.query(sql, [viewerId || 0, userId]);
 
    const BASE_URL = process.env.BASE_URL || 'http://187.124.37.68:3000';
    function toAbs(url) {
      if (!url) return null;
      return url.startsWith('http') ? url : `${BASE_URL}${url}`;
    }
    function cleanMp4(url) {
      if (!url) return null;
      const m = url.match(/.*\.mp4/);
      return m ? m[0] : url;
    }
 
    const mapped = posts.map(p => ({
      ...p,
      media_url:          cleanMp4(toAbs(p.media_url)),
      thumbnail_url:      toAbs(p.thumbnail_url),
      author_photo:       toAbs(p.author_photo),
      low_quality_url:    toAbs(p.low_quality_url),
      medium_quality_url: toAbs(p.medium_quality_url),
      high_quality_url:   toAbs(p.high_quality_url),
    }));
 
    res.status(200).json(mapped);
 
  } catch (error) {
    console.error('getUserPosts error:', error);
    res.status(500).json({ message: 'Server error while fetching user posts.' });
  }
};

