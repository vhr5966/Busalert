/// Application-wide constants for BusAlert Cardiff.
///
/// Centralizes API URLs, detection thresholds, and other magic numbers
/// so they can be easily changed and referenced from comments.
library;

// ─── Firebase ──────────────────────────────────────────────────────────

/// Name of the Firestore collection for bus stops.
const String kStopsCollection = 'bus_stops';

/// Name of the Firestore collection for journey records.
const String kJourneysCollection = 'journeys';

/// Name of the Firebase Cloud Function for delay prediction.
const String kPredictionFunctionName = 'getPrediction';

// ─── Common Cardiff Bus Lines ────────────────────────────────────────────

/// Common Cardiff Bus route numbers for autocomplete suggestions.
const List<String> kCommonBusLines = [
  '1', '2', '6', '8', '9', '17', '18', '21', '23', '24', '25', '27', '28', 
  '29', '30', '32', '44', '45', '95', 'X2', '304'
];

// ─── GPS Boarding / Alighting Detection Thresholds ───────────────────────

/// Maximum distance (in meters) from a known bus stop to consider
/// a boarding or alighting event.
const double kStopProximityMeters = 50.0;

/// Speed threshold (in km/h) — if the user exceeds this speed AND is
/// near a stop, we consider them to have boarded the bus.
const double kBoardingSpeedThresholdKmh = 7.0;

/// Minimum dwell time (in seconds) near a stop at low speed to confirm
/// alighting. Prevents false positives from temporary slowdowns.
const int kAlightingDwellSeconds = 15;

/// Interval (in seconds) between GPS position samples during active tracking.
const int kGpsPollIntervalSeconds = 5;

/// Minimum distance (in meters) travelled between GPS samples to register
/// a meaningful movement update.
const double kSignificantMovementMeters = 10.0;

// ─── Cardiff Bus Stop Data ──────────────────────────────────────────────

/// A comprehensive seed list of Cardiff Bus stops.
///
/// These stops cover Cardiff city centre and key suburbs. They are used:
/// 1. As the fallback when Firestore is unavailable.
/// 2. As the initial seed data to populate the `bus_stops` Firestore
///    collection — run [StopService.seedFirestore] once after project setup.
///
/// Each stop now includes a 'routes' field listing which Cardiff Bus routes
/// serve that stop. This enables route-based filtering in the prediction screen.
///
/// Coordinates sourced from publicly available Cardiff Bus timetable data
/// and OpenStreetMap (openstreetmap.org).
const List<Map<String, dynamic>> kCardiffReferenceStops = [
  // ── City Centre ──────────────────────────────────────────────────────
  {
    'id': 1,
    'name': 'Cardiff Central Station',
    'latitude': 51.4757,
    'longitude': -3.1791,
    'routes': ['1', '2', '6', '8', '9', '17', '18', '21', '24', '25', '27', '28', '29', '30', '95', 'X2', '304'],
  },
  {
    'id': 2,
    'name': 'Westgate Street (Stop WJ)',
    'latitude': 51.4778,
    'longitude': -3.1789,
    'routes': ['1', '6', '8', '9', '17', '18', '25', '29', '95', 'X2', '304'],
  },
  {
    'id': 3,
    'name': 'Castle Street (Stop CK)',
    'latitude': 51.4813,
    'longitude': -3.1805,
    'routes': ['2', '6', '9', '17', '18', '21', '27', '28', 'X2', '304'],
  },
  {
    'id': 4,
    'name': 'Queen Street (Stop QY)',
    'latitude': 51.4817,
    'longitude': -3.1705,
    'routes': ['2', '6', '8', '9', '17', '18', '21', '23', '24', '27', '28', '29', 'X2', '304'],
  },
  {
    'id': 5,
    'name': 'Cardiff Bus Station (Stop A)',
    'latitude': 51.4801,
    'longitude': -3.1766,
    'routes': ['1', '2', '6', '8', '9', '17', '18', '21', '23', '24', '25', '27', '28', '29', '30', '32', '44', '45', 'X2', '304'],
  },
  {
    'id': 6,
    'name': 'Cardiff Bus Station (Stop B)',
    'latitude': 51.4803,
    'longitude': -3.1762,
    'routes': ['1', '2', '6', '8', '9', '17', '18', '21', '23', '24', '25', '27', '28', '29', '30', '32', '44', '45', 'X2', '304'],
  },
  {
    'id': 7,
    'name': 'St Mary Street (Stop SM)',
    'latitude': 51.4775,
    'longitude': -3.1772,
    'routes': ['1', '8', '9', '17', '18', '95'],
  },
  {
    'id': 8,
    'name': 'Wood Street (Stop WS)',
    'latitude': 51.4760,
    'longitude': -3.1784,
    'routes': ['1', '8', '25', '95'],
  },
  {
    'id': 9,
    'name': 'Park Place (Stop PP)',
    'latitude': 51.4854,
    'longitude': -3.1753,
    'routes': ['6', '9', '17', '18', '21', '27', '28'],
  },
  {
    'id': 10,
    'name': 'Greyfriars Road (Stop GF)',
    'latitude': 51.4833,
    'longitude': -3.1749,
    'routes': ['6', '9', '17', '18', '21', '27', '28'],
  },
  // ── North Cardiff ─────────────────────────────────────────────────────
  {
    'id': 11,
    'name': 'Cathays Station',
    'latitude': 51.4881,
    'longitude': -3.1884,
    'routes': ['9', '17', '18', '21', '23', '27', '28'],
  },
  {
    'id': 12,
    'name': 'University of Cardiff (Stop UC)',
    'latitude': 51.4837,
    'longitude': -3.1807,
    'routes': ['9', '17', '18', '21', '27', '28'],
  },
  {
    'id': 13,
    'name': 'Roath Park',
    'latitude': 51.5010,
    'longitude': -3.1754,
    'routes': ['6', '27', '28'],
  },
  {
    'id': 14,
    'name': 'Heath Hospital',
    'latitude': 51.5177,
    'longitude': -3.1817,
    'routes': ['6', '27', '28', '29'],
  },
  {
    'id': 15,
    'name': 'Birchgrove',
    'latitude': 51.5230,
    'longitude': -3.2020,
    'routes': ['6', '29'],
  },
  {
    'id': 16,
    'name': 'Llanishen',
    'latitude': 51.5302,
    'longitude': -3.1911,
    'routes': ['27', '28', '29'],
  },
  {
    'id': 17,
    'name': 'Thornhill',
    'latitude': 51.5455,
    'longitude': -3.2017,
    'routes': ['6', '29'],
  },
  // ── East Cardiff ──────────────────────────────────────────────────────
  {
    'id': 18,
    'name': 'City Road (Stop CP)',
    'latitude': 51.4875,
    'longitude': -3.1625,
    'routes': ['2', '8', '9', '18'],
  },
  {
    'id': 19,
    'name': 'Roath (Newport Road)',
    'latitude': 51.4893,
    'longitude': -3.1557,
    'routes': ['2', '8', '18', '30'],
  },
  {
    'id': 20,
    'name': 'Rumney',
    'latitude': 51.4964,
    'longitude': -3.1215,
    'routes': ['2', '8', '30'],
  },
  {
    'id': 21,
    'name': 'Trowbridge',
    'latitude': 51.5067,
    'longitude': -3.0968,
    'routes': ['8', '30'],
  },
  // ── West Cardiff ──────────────────────────────────────────────────────
  {
    'id': 22,
    'name': 'Canton (Cowbridge Road)',
    'latitude': 51.4795,
    'longitude': -3.2030,
    'routes': ['8', '17', '18', '24', '25', '32'],
  },
  {
    'id': 23,
    'name': 'Llandaff',
    'latitude': 51.4930,
    'longitude': -3.2230,
    'routes': ['24', '25', '32'],
  },
  {
    'id': 24,
    'name': 'Fairwater',
    'latitude': 51.4844,
    'longitude': -3.2365,
    'routes': ['24', '25'],
  },
  {
    'id': 25,
    'name': 'Ely',
    'latitude': 51.4839,
    'longitude': -3.2520,
    'routes': ['24', '30'],
  },
  {
    'id': 26,
    'name': 'St Fagans',
    'latitude': 51.4949,
    'longitude': -3.2767,
    'routes': ['32'],
  },
  // ── South Cardiff / Bay ───────────────────────────────────────────────
  {
    'id': 27,
    'name': 'Cardiff Bay',
    'latitude': 51.4647,
    'longitude': -3.1650,
    'routes': ['1', '6', '8', '95'],
  },
  {
    'id': 28,
    'name': 'Butetown',
    'latitude': 51.4680,
    'longitude': -3.1727,
    'routes': ['1', '6', '95'],
  },
  {
    'id': 29,
    'name': 'Grangetown',
    'latitude': 51.4703,
    'longitude': -3.1879,
    'routes': ['8', '9', '17', '18'],
  },
  {
    'id': 30,
    'name': 'Penarth Road (Stop PR)',
    'latitude': 51.4712,
    'longitude': -3.1789,
    'routes': ['8', '9', '44', '45'],
  },
];
