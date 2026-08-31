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
const liveBusesController = require('../controllers/liveBusesController');
const routeController = require('../controllers/routeController');
const { authenticateToken } = require('../middleware/auth');

// ── Auth Routes ────────────────────────────────────────────────────
router.post('/auth/register', authController.register);
router.post('/auth/login', authController.login);

// ── Journey Routes (authenticated) ─────────────────────────────────
router.post('/journeys', authenticateToken, journeyController.submitJourney);
router.get('/journeys/history', authenticateToken, journeyController.getHistory);

// ── Live Buses Route ───────────────────────────────────────────────
router.get('/live-buses', liveBusesController.getLiveBuses);
router.get('/trip-updates', liveBusesController.getTripUpdates);

// ── Official Routes Endpoint ───────────────────────────────────────
router.get('/routes', routeController.getRoutes);

// ── Service Alerts Endpoint ────────────────────────────────────────
const serviceAlertsController = require('../controllers/serviceAlertsController');
router.get('/service-alerts', serviceAlertsController.getServiceAlerts);

// ── Prediction Route ───────────────────────────────────────────────
router.get('/predictions', predictionController.getPrediction);

// ── Stops Route ────────────────────────────────────────────────────
router.get('/stops', stopController.getStops);

module.exports = router;
