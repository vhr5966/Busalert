// ============================================================================
// BusAlert Cardiff — Firebase Cloud Functions
//
// This file implements the delay prediction algorithm as a callable Firebase
// Cloud Function. The Flutter app calls this function when the user queries
// for a delay prediction.
//
// ## Prediction Algorithm (for dissertation)
//
// The function computes a predicted delay for a given bus stop, bus line,
// and time of day using a **weighted moving average** of historical journey
// durations stored in Firestore.
//
// ### Algorithm Steps:
//
// 1. Query Firestore for journeys matching the requested stop_id and bus_line.
// 2. Filter by time proximity (±60 minutes around the requested time).
// 3. Calculate the scheduled duration as the median of all recorded journey
//    durations for that route (since we don't have the official timetable API).
// 4. Compute a weighted average where:
//    - Recent journeys (< 30 days old) get double weight
//    - Journeys at similar times get higher weight (±15 min → 2x)
// 5. Determine confidence level based on sample size (≥20 = High, ≥10 = Medium).
//
// This function can later be replaced with a proper ML model without changing
// the app's API contract.
// ============================================================================

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.getPrediction = functions.https.onCall(async (data, context) => {
  const { stopId, busLine, timeOfDay } = data;

  // Validate input
  if (!stopId || !busLine || !timeOfDay) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'stopId, busLine, and timeOfDay are required.'
    );
  }

  const [hours, minutes] = timeOfDay.split(':').map(Number);
  if (isNaN(hours) || isNaN(minutes)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid time format. Use HH:mm.'
    );
  }

  try {
    // Query Firestore for matching journeys
    const queryTimeMinutes = hours * 60 + minutes;
    const journeysSnapshot = await db.collection('journeys')
      .where('bus_line', '==', busLine)
      .where('board_stop_id', '==', parseInt(stopId))
      .orderBy('boarding_time', 'desc')
      .limit(200)
      .get();

    if (journeysSnapshot.empty) {
      return {
        predicted_delay_minutes: 0,
        scheduled_duration_minutes: 0,
        average_actual_duration_minutes: 0,
        confidence_level: 'Low',
        sample_size: 0,
        stop_name: '',
        bus_line: busLine,
        time_of_day: timeOfDay,
      };
    }

    // Filter journeys with alighting times within time window
    const journeys = [];
    for (const doc of journeysSnapshot.docs) {
      const j = doc.data();
      if (!j.alighting_time) continue;

      const boardTime = j.boarding_time.toDate
        ? j.boarding_time.toDate()
        : new Date(j.boarding_time);
      const alightTime = j.alighting_time.toDate
        ? j.alighting_time.toDate()
        : new Date(j.alighting_time);

      const journeyMinutes = boardTime.getHours() * 60 + boardTime.getMinutes();
      const timeDiff = Math.abs(journeyMinutes - queryTimeMinutes);

      if (timeDiff <= 60) {
      const duration = (alightTime - boardTime) / 60000;
      const stopName = j['board_stop_name'] || '';
      journeys.push({ boardTime, duration, timeDiff, stopName });
      }
    }

    if (journeys.length === 0) {
      return {
        predicted_delay_minutes: 0,
        scheduled_duration_minutes: 0,
        average_actual_duration_minutes: 0,
        confidence_level: 'Low',
        sample_size: 0,
        stop_name: '',
        bus_line: busLine,
        time_of_day: timeOfDay,
      };
    }

    // Calculate scheduled duration (median)
    const durations = journeys.map(j => j.duration).sort((a, b) => a - b);
    const medianDuration = durations[Math.floor(durations.length / 2)];

    // Weighted moving average
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    let totalWeight = 0;
    let weightedSum = 0;

    for (const journey of journeys) {
      const actualDuration = journey.duration;
      const recencyWeight = journey.boardTime.getTime() > thirtyDaysAgo ? 2.0 : 1.0;
      const timeWeight = journey.timeDiff <= 15 ? 2.0 : journey.timeDiff <= 30 ? 1.5 : 1.0;
      const weight = recencyWeight * timeWeight;
      const delay = actualDuration - medianDuration;

      weightedSum += delay * weight;
      totalWeight += weight;
    }

    const predictedDelay = totalWeight > 0 ? weightedSum / totalWeight : 0;
    const avgActualDuration = durations.reduce((s, d) => s + d, 0) / durations.length;
    const sampleSize = journeys.length;
    const confidenceLevel = sampleSize >= 20 ? 'High' : sampleSize >= 10 ? 'Medium' : 'Low';

    return {
      predicted_delay_minutes: Math.round(predictedDelay * 10) / 10,
      scheduled_duration_minutes: Math.round(medianDuration * 10) / 10,
      average_actual_duration_minutes: Math.round(avgActualDuration * 10) / 10,
      confidence_level: confidenceLevel,
      sample_size: sampleSize,
      stop_name: journeys[0]?.stopName || '',
      bus_line: busLine,
      time_of_day: timeOfDay,
    };
  } catch (error) {
    console.error('Prediction error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to compute prediction.');
  }
});
