// ============================================================================
// Bus Stops Controller
//
// Returns the list of Cardiff Bus stops with GPS coordinates. The Flutter
// app uses this data to display the interactive map, detect nearby stops
// for boarding/alighting, and populate the stop selection dropdowns.
// ============================================================================

const pool = require('../models/index');

// ─── GET /api/stops ─────────────────────────────────────────────────────
exports.getStops = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, latitude, longitude FROM bus_stops ORDER BY name'
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Get stops error:', err);
    res.status(500).json({ error: 'Failed to fetch bus stops.' });
  }
};
