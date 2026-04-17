const db = require('../db');
 
/**
 * GET /api/app/version-policy
 * Public endpoint — no auth required.
 * Returns the current version policy so the app can decide whether to
 * force-update, show a soft update banner, or enter maintenance mode.
 */
exports.getVersionPolicy = async (req, res) => {
  try {
    const platform = (req.query.platform || 'both').toLowerCase();
 
    const [rows] = await db.query(
      `SELECT * FROM app_version_policy
       WHERE platform = ? OR platform = 'both'
       ORDER BY FIELD(platform, ?, 'both') DESC
       LIMIT 1`,
      [platform, platform]
    );
 
    if (!rows || rows.length === 0) {
      // Graceful fallback — never block the app if the table is missing
      return res.json({
        latest_version:   '1.0.0',
        minimum_version:  '1.0.0',
        force_update:     false,
        maintenance_mode: false,
        message:          'Up to date.',
        store_urls: { android: null, ios: null },
      });
    }
 
    const row = rows[0];
    return res.json({
      latest_version:   row.latest_version,
      minimum_version:  row.minimum_version,
      force_update:     row.force_update === 1 || row.force_update === true,
      maintenance_mode: row.maintenance_mode === 1 || row.maintenance_mode === true,
      message:          row.message,
      store_urls: {
        android: row.android_store_url || null,
        ios:     row.ios_store_url     || null,
      },
    });
  } catch (err) {
    console.error('[getVersionPolicy] error:', err.message);
    // Always return a safe fallback — never crash the app on a version check
    return res.json({
      latest_version:   '1.0.0',
      minimum_version:  '1.0.0',
      force_update:     false,
      maintenance_mode: false,
      message:          'Up to date.',
      store_urls: { android: null, ios: null },
    });
  }
};

exports.updateVersionPolicy = async (req, res) => {
  // Simple admin key check — replace with your real admin middleware
  const adminKey = req.headers['x-admin-key'];
  if (!adminKey || adminKey !== process.env.ADMIN_SECRET_KEY) {
    return res.status(403).json({ message: 'Forbidden' });
  }
 
  try {
    const {
      latest_version,
      minimum_version,
      force_update     = false,
      maintenance_mode = false,
      message          = 'A new version is available.',
      android_store_url = null,
      ios_store_url     = null,
      platform          = 'both',
    } = req.body;
 
    // minimum_version is what the mobile app uses to block older builds.
    if (!latest_version || !minimum_version) {
      return res.status(400).json({ message: 'latest_version and minimum_version are required' });
    }
 
    // Validate semver format (x.y.z)
    const semverRe = /^\d+\.\d+\.\d+$/;
    if (!semverRe.test(latest_version) || !semverRe.test(minimum_version)) {
      return res.status(400).json({ message: 'Versions must be in x.y.z format' });
    }
 
    await db.query(
      `INSERT INTO app_version_policy
         (platform, latest_version, minimum_version, force_update, maintenance_mode,
          message, android_store_url, ios_store_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         latest_version   = VALUES(latest_version),
         minimum_version  = VALUES(minimum_version),
         force_update     = VALUES(force_update),
         maintenance_mode = VALUES(maintenance_mode),
         message          = VALUES(message),
         android_store_url= VALUES(android_store_url),
         ios_store_url    = VALUES(ios_store_url)`,
      [
        platform, latest_version, minimum_version,
        force_update ? 1 : 0,
        maintenance_mode ? 1 : 0,
        message, android_store_url, ios_store_url,
      ]
    );
 
    return res.json({ success: true, message: 'Version policy updated.' });
  } catch (err) {
    console.error('[updateVersionPolicy] error:', err.message);
    return res.status(500).json({ message: 'Server error' });
  }
};
