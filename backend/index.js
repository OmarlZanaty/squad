require("dotenv").config();
const express = require("express");



const cors = require("cors");
const path = require("path");
const morgan = require("morgan");
const db = require("./db");
const Auth = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// ❌ DELETE THIS ENTIRE BLOCK (lines at the top):
app.use((req, res, next) => {
  let decodedUrl = decodeURIComponent(req.url);
  if (decodedUrl.includes('.mp4/') || decodedUrl.match(/\.mp4\/+$/)) {
    const cleanUrl = decodedUrl.replace(/\/+$/, '').replace(/\.mp4\/.+/, '.mp4');
    console.log('🔁 Redirecting:', req.url, '→', cleanUrl);
    return res.redirect(301, encodeURI(cleanUrl));
  }
  next();
});

app.use('/api/app', require('./routes/appVersion'));

// ✅ REPLACE your /storage static with this (add redirect: false):
app.use('/storage', express.static(path.join(__dirname, 'storage'), {
  maxAge: '30d',
  etag: true,
  lastModified: true,
  redirect: false,  // ✅ THIS IS THE KEY FIX
  setHeaders: (res, filePath) => {
    if (filePath.match(/\.(jpg|jpeg|png|webp|gif)$/)) {
      res.setHeader('Cache-Control', 'public, max-age=2592000, immutable');
    }
    if (filePath.match(/\.(mp4|webm|mov)$/)) {
      res.setHeader('Content-Type', 'video/mp4');
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Cache-Control', 'public, max-age=86400');
      res.setHeader('Access-Control-Allow-Origin', '*');
    }
  }
}));

  const postController = require('./controllers/postController');
  postController.ensureVideoQualityColumns()
     .then(() => console.log('✅ Video quality columns ensured'))
     .catch(e => console.warn('⚠️ ensureVideoQualityColumns:', e.message));

   

// Serve landing page static files at /landing
app.use('/landing', express.static(
  path.join(__dirname, 'public/landing')
));

// Explicitly serve script.js to avoid being overwritten by other routes
app.get('/landing/script.js', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/script.js'));
});

// Optional: if user opens /landing without a trailing file, serve index.html
app.get('/landing', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/index.html'));
});

// Profile Routes
const profileRoutes = require('./routes/profileRoutes');
app.use('/api/profiles', profileRoutes);

// Logging Middleware
app.use(morgan("dev"));

// CORS Configuration
app.use(cors({
  origin: "*",
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "x-admin-key"],
}));

app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({ success: false, message: err.message || "Server error" });
});

// Body Parsers
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ads Router
const adsRouter = require("./routes/ads.router");
app.use("/api/ads", adsRouter);

// Static Files
app.use("/api/auth", Auth);
app.use("/uploads", express.static(path.join(__dirname, "uploads")));
app.use("/assets", express.static(path.join(__dirname, "assets")));
app.use("/public", express.static(path.join(__dirname, "public")));

// Admin Dashboard (static)
app.use("/admin", express.static(path.join(__dirname, "admin")));
app.get("/admin", (req, res) => {
  res.sendFile(path.join(__dirname, "admin", "index.html"));
});

// Attach DB
app.set("db", db);

// API ROUTES
app.use("/api/posts", require("./routes/posts"));
app.use("/api/users", require("./routes/user"));
app.use("/api/chats", require("./routes/chat"));
app.use("/api/messages", require("./routes/messages"));
app.use("/api/comments", require("./routes/comments"));
app.use("/api/notifications", require("./routes/notifications"));
app.use("/api/media", require("./routes/media"));
app.use("/api/career", require("./routes/career"));
app.use("/api/admin/dashboard", require("./backend_admin_routes_no_auth"));
app.use("/api/admin", require("./routes/admin"));

// Compliance routes and deep links
app.get("/__admin_test", (req, res) => {
  res.sendFile(path.join(__dirname, "admin", "index.html"));
});


app.use('/.well-known', express.static(path.join(__dirname, 'public/.well-known')));
// Serve landing assets
app.use('/landing', express.static(path.join(__dirname, 'public/landing')));

// Serve script.js explicitly so it doesn’t get rewritten to HTML
app.get('/landing/script.js', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/script.js'));
});

// If someone visits /landing without a filename, serve the landing page
app.get('/landing', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/index.html'));
});

// Deep-link pages
app.get('/post/:id', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/open-app.html'));
});
app.get('/profile/:id', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/landing/open-app.html'));
});



// Health Check
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public/landing/index.html"));
});

app.get('/delete-account', (req, res) => {
  res.sendFile(path.join(__dirname, 'public/delete-account.html'));
});

// Compliance MUST be last
app.use("/compliance", require("./routes/compliance"));


// Start server
const startServer = async () => {
  try {
    await db.query("SELECT 1");
    console.log("✅ Database connection successful");
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📊 Admin Dashboard: http://localhost:${PORT}/admin`);
    });
  } catch (error) {
    console.error("❌ DB connection failed:", error.message);
    process.exit(1);
  }
};
startServer();