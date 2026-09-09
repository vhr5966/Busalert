// ============================================================================
// Bus Stops Controller
//
// Returns the list of Cardiff Bus stops with GPS coordinates. The Flutter
// app uses this data to display the interactive map, detect nearby stops
// for boarding/alighting, and populate the stop selection dropdowns.
// ============================================================================

const fs = require('fs');
const path = require('path');
const pool = require('../models/index');

const STOPS_FILE = path.join(__dirname, '../../data/stops.json');
let cachedStops = null;

function loadCompleteStops() {
  if (!cachedStops && fs.existsSync(STOPS_FILE)) {
    try {
      cachedStops = JSON.parse(fs.readFileSync(STOPS_FILE, 'utf8'));
    } catch (e) {
      console.error('Failed to parse stops.json:', e);
    }
  }
  return cachedStops || [];
}

// ─── GET /api/stops ─────────────────────────────────────────────────────
exports.getStops = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, latitude, longitude FROM bus_stops ORDER BY name'
    );

    if (result && result.rows && result.rows.length >= 100) {
      return res.json(result.rows);
    }

    // If database only has minimal seed data, return the comprehensive 1650 stops
    const allStops = loadCompleteStops();
    res.json(allStops);
  } catch (err) {
    console.error('Get stops error:', err);
    const fallbackStops = loadCompleteStops();
    res.json(fallbackStops);
  }
};

