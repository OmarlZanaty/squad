const jwt = require('jsonwebtoken');

// Middleware to verify a standard user's JWT
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Expects "Bearer TOKEN"

  if (token == null) return res.sendStatus(401); // No token, unauthorized

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403); // Token is invalid, forbidden
    req.user = user; // Add user payload to the request object
    next();
  });
}

// Middleware to verify the admin's secret API key
function isAdmin(req, res, next) {
  const adminApiKey = req.headers['x-admin-api-key'];
  if (adminApiKey && adminApiKey === process.env.ADMIN_API_KEY) {
    next(); // Key is valid, proceed
  } else {
    res.status(403).json({ message: "Forbidden: Invalid admin API key." });
  }
}

module.exports = { authenticateToken, isAdmin };
