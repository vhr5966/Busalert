// ============================================================================
// Express Route Definitions
//
// Maps API endpoints to their controller functions.
// Routes marked with [Auth] require a valid JWT token.
// ============================================================================

const express = require('express');
const router = express.Router();

const authController = require('../controllers/authController');
const journeyController = require('../controllers/journeyController');
const predictionController = require('../controllers/predictionController');
const stopController = require('../controllers/stopController');
const { authenticateToken } = require('../middleware/auth');

// ── Auth Routes ────────────────────────────────────────────────────
router.post('/auth/register', authController.register);
router.post('/auth/login', authController.login);

// ── Journey Routes (authenticated) ─────────────────────────────────
router.post('/journeys', authenticateToken, journeyController.submitJourney);
router.get('/journeys/history', authenticateToken, journeyController.getHistory);

// ── Prediction Route ───────────────────────────────────────────────
router.get('/predictions', predictionController.getPrediction);

// ── Stops Route ────────────────────────────────────────────────────
router.get('/stops', stopController.getStops);

module.exports = router;
