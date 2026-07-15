// ============================================================================
// BusAlert Cardiff — Backend Server
//
// Entry point for the Express.js REST API server.
//
// Start with: npm start
// Dev mode:   npm run dev (auto-restart on file changes)
//
// Environment variables are loaded from .env (see .env.example).
// ============================================================================

const express = require('express');
const cors = require('cors');
require('dotenv').config();

const routes = require('./routes');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ─────────────────────────────────────────────────────────

// CORS: Allow requests from the Flutter app (runs on a different port/address)
app.use(cors({
  origin: '*', // In production, restrict to your app's domain
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Parse JSON request bodies (limit: 10 MB for journey payloads)
app.use(express.json({ limit: '10mb' }));

// Request logging
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(
      `${req.method} ${req.originalUrl} → ${res.statusCode} (${duration}ms)`
    );
  });
  next();
});

// ── Routes ─────────────────────────────────────────────────────────────
app.use('/api', routes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'busalert-backend', timestamp: new Date().toISOString() });
});

// ── Error Handler ──────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error.' });
});

// ── Start Server ───────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🚌 BusAlert Cardiff backend running on http://localhost:${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/health`);
  console.log(`   API:    http://localhost:${PORT}/api\n`);
});
