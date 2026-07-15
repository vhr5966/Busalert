// ============================================================================
// JWT Authentication Middleware
//
// Verifies the Bearer token in the Authorization header and attaches the
// decoded user payload (id, email) to req.user so downstream controllers
// can identify the authenticated user.
//
// Usage in routes:
//   router.get('/protected', authenticateToken, (req, res) => { ... });
//
// The token is generated on login/register and stored securely on the client.
// ============================================================================

const jwt = require('jsonwebtoken');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET || 'busalert-dev-secret-key';

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"

  if (!token) {
    return res.status(401).json({ error: 'Access denied. No token provided.' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded; // Contains { id, email } from the token payload
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired. Please log in again.' });
    }
    return res.status(403).json({ error: 'Invalid token.' });
  }
}

module.exports = { authenticateToken, JWT_SECRET };
