const express = require("express");
const router = express.Router();

const {
  getHomeAds,
  patchSlot,
} = require("../services/systemSettingsAds.service");

const multer = require("multer");
const path = require("path");
const fs = require("fs");

const uploadDir = path.join(__dirname, "..", "public", "ads");
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase();
    const slot = req.params.slot;
    cb(null, `slot_${slot}_${Date.now()}${ext || ".png"}`);
  },
});

// ✅ Public: Flutter reads home ads
router.get("/ads", async (req, res, next) => {
  try {
    const data = await getHomeAds(req);
    // return items with finalImageUrl so flutter can show absolute link
    res.json({ success: true, data: data.items });
  } catch (e) {
    next(e);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

router.post("/admin/ads/:slot/image", requireAdmin, upload.single("image"), async (req, res, next) => {
  try {
    const slot = Number(req.params.slot);
    if (!slot || slot < 1 || slot > 3) {
      return res.status(400).json({ success: false, message: "Invalid slot" });
    }
    if (!req.file) {
      return res.status(400).json({ success: false, message: "No file uploaded (field name must be image)" });
    }

    // save relative path in DB
    const imageUrl = `/public/ads/${req.file.filename}`;

    const data = await patchSlot(slot, { imageUrl }, null);
    res.json({ success: true, data, imageUrl });
  } catch (e) {
    next(e);
  }
});

function requireAdmin(req, res, next) {
  const key = req.headers["x-admin-key"];
  const ADMIN_KEY = process.env.ADMIN_KEY;

  if (!ADMIN_KEY) {
    return res.status(500).json({ success: false, message: "ADMIN_KEY not set in .env" });
  }
  if (!key || key !== ADMIN_KEY) {
    return res.status(401).json({ success: false, message: "Unauthorized" });
  }
  next();
}

// ✅ Public: Flutter reads home ads
router.get("/admin/ads", requireAdmin, async (req, res, next) => {
  
  try {
    const data = await getHomeAds(req);
res.json({ success: true, data: data.items });
  } catch (e) {
    next(e);
  }
});

// ✅ Admin: update a slot (example endpoint)
router.put("/admin/ads/:slot", requireAdmin, async (req, res, next) => {  try {
    const slot = Number(req.params.slot);
    const patch = req.body || {};
    const data = await patchSlot(slot, patch, null);
    res.json({ success: true, data });
  } catch (e) {
    next(e);
  }
});



module.exports = router;
