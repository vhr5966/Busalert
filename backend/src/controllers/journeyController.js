// ============================================================================
// Journey Controller
//
// Handles:
//   POST /api/journeys      - Submit a completed journey record
//   GET  /api/journeys/history - Get the logged-in user's journey history
//
// The journey submission endpoint is called by the Flutter app when a
// boarding->alighting cycle is detected. It accepts both auto-detected
// and manually-entered journeys.
//
// Offline queueing is handled client-side; the server simply accepts
// journey records as they arrive.
// ============================================================================

const pool = require('../models/index');

// ─── POST /api/journeys ─────────────────────────────────────────────────
exports.submitJourney = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      board_stop_id, board_stop_name, board_lat, board_lng,
      alight_stop_id, alight_stop_name, alight_lat, alight_lng,
      bus_line, boarding_time, alighting_time,
    } = req.body;

    // Validate required fields
    if (!board_stop_id || !bus_line || !boarding_time) {
      return res.status(400).json({
        error: 'board_stop_id, bus_line, and boarding_time are required.',
      });
    }

    // Insert the journey record
    const result = await pool.query(
      `INSERT INTO journeys
         (user_id, board_stop_id, board_stop_name, board_lat, board_lng,
          alight_stop_id, alight_stop_name, alight_lat, alight_lng,
          bus_line, boarding_time, alighting_time)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       ON CONFLICT (user_id, boarding_time, bus_line, board_stop_id)
         DO UPDATE SET alighting_time = EXCLUDED.alighting_time,
                       alight_stop_id = EXCLUDED.alight_stop_id,
                       alight_stop_name = EXCLUDED.alight_stop_name,
                       alight_lat = EXCLUDED.alight_lat,
                       alight_lng = EXCLUDED.alight_lng
       RETURNING id`,
      [
        userId,
        board_stop_id,
        board_stop_name || '',
        board_lat,
        board_lng,
        alight_stop_id || null,
        alight_stop_name || null,
        alight_lat || null,
        alight_lng || null,
        bus_line,
        boarding_time,
        alighting_time || null,
      ]
    );

    res.status(201).json({
      id: result.rows[0].id,
      message: 'Journey recorded successfully.',
    });
  } catch (err) {
    console.error('Submit journey error:', err);
    res.status(500).json({ error: 'Failed to record journey.' });
  }
};

// ─── GET /api/journeys/history ──────────────────────────────────────────
exports.getHistory = async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      `SELECT id, user_id, board_stop_id, board_stop_name,
              board_lat, board_lng,
              alight_stop_id, alight_stop_name,
              alight_lat, alight_lng,
              bus_line, boarding_time, alighting_time
       FROM journeys
       WHERE user_id = $1
       ORDER BY boarding_time DESC
       LIMIT 100`,
      [userId]
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Get history error:', err);
    res.status(500).json({ error: 'Failed to fetch journey history.' });
  }
};
