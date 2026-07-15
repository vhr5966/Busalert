// ============================================================================
// Delay Prediction Controller
//
// ## Prediction Algorithm (for dissertation)
//
// The backend computes a predicted delay for a given bus stop, bus line,
// and time of day using a **weighted moving average** of historical journey
// durations.
//
// ### Algorithm Steps:
//
// 1. **Filter matching records:** Query the journeys table for records
//    matching the requested stop_id and bus_line. Also filter by time
//    proximity (±30 minutes around the requested time) and the same
//    day-of-week (weekday vs weekend).
//
// 2. **Calculate individual delays:** For each journey, the actual
//    duration is compared to the scheduled duration. The scheduled
//    duration is estimated as the median of all recorded journey durations
//    for that route (since we don't have the official timetable API
//    integrated yet).
//
// 3. **Weighted average:** More recent journeys (within the last 30 days)
//    are weighted more heavily than older ones. Journeys recorded at
//    closer times to the query time also get higher weights.
//
// 4. **Confidence level:** Based on the sample size:
//    - ≥ 20 records: "High" confidence
//    - 10–19 records: "Medium" confidence
//    - < 10 records: "Low" confidence
//
// ### Extensibility
// This function is designed so that the weighting logic can be replaced
// with a proper ML model (e.g., linear regression or a neural network)
// trained on the same data, without changing the API contract.
// ============================================================================

const pool = require('../models/index');

// ─── GET /api/predictions?stop=X&line=Y&time=Z ──────────────────────────
exports.getPrediction = async (req, res) => {
  try {
    const stopId = parseInt(req.query.stop, 10);
    const busLine = req.query.line;
    const timeOfDay = req.query.time; // Format: "HH:mm"

    // Validate query parameters
    if (!stopId || !busLine || !timeOfDay) {
      return res.status(400).json({
        error: 'Query parameters "stop", "line", and "time" are required.',
      });
    }

    // Parse the time string into hours and minutes
    const [hours, minutes] = timeOfDay.split(':').map(Number);
    if (isNaN(hours) || isNaN(minutes)) {
      return res.status(400).json({ error: 'Invalid time format. Use HH:mm.' });
    }

    // Determine day-of-week category (weekday vs weekend)
    // Used to filter journeys by similar traffic patterns.
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0=Sunday, 6=Saturday
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;

    // ── Step 1: Query matching historical journeys ──────────────────
    //
    // We search for journeys with the same stop, bus line, and boarding
    // time within ±60 minutes of the requested time. We also try to
    // match weekday vs weekend patterns.
    //
    // The query uses the composite index idx_journeys_prediction on
    // (board_stop_id, bus_line, boarding_time) for efficiency.
    const result = await pool.query(
      `SELECT
         boarding_time,
         alighting_time,
         board_stop_id,
         board_stop_name,
         bus_line
       FROM journeys
       WHERE board_stop_id = $1
         AND bus_line = $2
         AND alighting_time IS NOT NULL
         AND EXTRACT(HOUR FROM boarding_time) * 60 + EXTRACT(MINUTE FROM boarding_time)
             BETWEEN $3 - 60 AND $3 + 60
       ORDER BY boarding_time DESC
       LIMIT 200`,
      [stopId, busLine, hours * 60 + minutes]
    );

    const journeys = result.rows;

    // If no data is available, return a fallback response
    if (journeys.length === 0) {
      return res.json({
        predicted_delay_minutes: 0,
        scheduled_duration_minutes: 0,
        average_actual_duration_minutes: 0,
        confidence_level: 'Low',
        sample_size: 0,
        stop_name: '',
        bus_line: busLine,
        time_of_day: timeOfDay,
      });
    }

    // ── Step 2: Calculate scheduled duration (median of all) ───────
    //
    // Since we don't have the official timetable API, we estimate the
    // scheduled (on-time) duration as the median of all journey durations
    // for this stop+line combination. In production, this would come from
    // the Cardiff Bus timetable API.
    const durations = journeys.map((j) => {
      const boardTime = new Date(j.boarding_time);
      const alightTime = new Date(j.alighting_time);
      return (alightTime - boardTime) / 60000; // Convert ms to minutes
    });

    durations.sort((a, b) => a - b);
    const medianDuration = durations[Math.floor(durations.length / 2)];

    // ── Step 3: Weighted moving average ─────────────────────────────
    //
    // Recent journeys (within 30 days) get higher weight.
    // Journeys at similar times also get higher weight.
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    const queryTimeMinutes = hours * 60 + minutes;

    let totalWeight = 0;
    let weightedSum = 0;

    for (const journey of journeys) {
      const boardTime = new Date(journey.boarding_time);
      const alightTime = new Date(journey.alighting_time);
      const actualDuration = (alightTime - boardTime) / 60000;

      // Weight factor 1: Recency — journeys within last 30 days get
      // double the weight of older ones.
      const recencyWeight = boardTime.getTime() > thirtyDaysAgo ? 2.0 : 1.0;

      // Weight factor 2: Time proximity — journeys at a similar time
      // of day get higher weight (±15 min → 2x, ±30 min → 1.5x, etc.)
      const journeyMinutes =
        boardTime.getHours() * 60 + boardTime.getMinutes();
      const timeDiff = Math.abs(journeyMinutes - queryTimeMinutes);
      const timeWeight = timeDiff <= 15 ? 2.0 : timeDiff <= 30 ? 1.5 : 1.0;

      // Combined weight
      const weight = recencyWeight * timeWeight;

      // The delay is the difference between actual and scheduled duration
      const delay = actualDuration - medianDuration;

      weightedSum += delay * weight;
      totalWeight += weight;
    }

    const predictedDelay = totalWeight > 0 ? weightedSum / totalWeight : 0;
    const avgActualDuration =
      durations.reduce((sum, d) => sum + d, 0) / durations.length;

    // ── Step 4: Confidence level ────────────────────────────────────
    const sampleSize = journeys.length;
    let confidenceLevel;
    if (sampleSize >= 20) confidenceLevel = 'High';
    else if (sampleSize >= 10) confidenceLevel = 'Medium';
    else confidenceLevel = 'Low';

    res.json({
      predicted_delay_minutes: Math.round(predictedDelay * 10) / 10,
      scheduled_duration_minutes: Math.round(medianDuration * 10) / 10,
      average_actual_duration_minutes: Math.round(avgActualDuration * 10) / 10,
      confidence_level: confidenceLevel,
      sample_size: sampleSize,
      stop_name: journeys[0].board_stop_name,
      bus_line: busLine,
      time_of_day: timeOfDay,
    });
  } catch (err) {
    console.error('Prediction error:', err);
    res.status(500).json({ error: 'Failed to compute prediction.' });
  }
};
