// ============================================================================
// Live Buses Controller
//
// Fetches real-time bus location data from authorized transport data providers
// (SIRI-VM XML or GTFS-Realtime), normalizes it, caches responses for 15–20s,
// and enforces security (API keys are kept strictly server-side).
// ============================================================================

const { XMLParser } = require('fast-xml-parser');
const GtfsRealtimeBindings = require('gtfs-realtime-bindings');

// Cardiff metropolitan geographical bounding box
const CARDIFF_BOUNDS = {
  minLat: 51.38,
  maxLat: 51.60,
  minLng: -3.38,
  maxLng: -3.02,
};

// In-memory cache
let cachedData = null; // { timestamp: number, responsePayload: object }
const CACHE_TTL_MS = 15000; // 15 seconds

/**
 * Parses ISO-8601 duration string (e.g., "PT2M", "-PT1M30S", "PT0S") to minutes.
 */
function parseIsoDurationToMinutes(durationStr) {
  if (!durationStr || typeof durationStr !== 'string') return 0;
  const isNegative = durationStr.startsWith('-');
  const match = durationStr.match(/P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?/i);
  if (!match) return 0;

  const days = parseInt(match[1] || '0', 10);
  const hours = parseInt(match[2] || '0', 10);
  const minutes = parseInt(match[3] || '0', 10);
  const seconds = parseFloat(match[4] || '0');

  let totalMinutes = days * 1440 + hours * 60 + minutes + seconds / 60;
  return isNegative ? -totalMinutes : totalMinutes;
}

/**
 * Validates if coordinates fall within valid Cardiff bounds.
 */
function isWithinCardiff(lat, lng) {
  if (typeof lat !== 'number' || typeof lng !== 'number') return false;
  if (isNaN(lat) || isNaN(lng) || lat === 0 || lng === 0) return false;
  return (
    lat >= CARDIFF_BOUNDS.minLat &&
    lat <= CARDIFF_BOUNDS.maxLat &&
    lng >= CARDIFF_BOUNDS.minLng &&
    lng <= CARDIFF_BOUNDS.maxLng
  );
}

/**
 * Parses SIRI-VM XML string into normalized vehicle array.
 */
function parseSiriVmXml(xmlText, approvedOperators) {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
    removeNSPrefix: true, // Strips siri: prefixes
  });

  const parsed = parser.parse(xmlText);
  const siri = parsed.Siri || parsed;
  const delivery =
    siri?.ServiceDelivery?.VehicleMonitoringDelivery ||
    siri?.VehicleMonitoringDelivery;

  if (!delivery) return [];

  const activitiesRaw = delivery.VehicleActivity;
  if (!activitiesRaw) return [];
  const activities = Array.isArray(activitiesRaw) ? activitiesRaw : [activitiesRaw];

  const nowMs = Date.now();
  const twoMinutesMs = 2 * 60 * 1000;
  const vehicles = [];

  for (const act of activities) {
    const recordedAtRaw = act.RecordedAtTime || act['@_RecordedAtTime'];
    const recordedAt = recordedAtRaw ? new Date(recordedAtRaw) : new Date();
    const recordedAtMs = recordedAt.getTime();

    // Ignore vehicle records older than 2 minutes
    if (isNaN(recordedAtMs) || nowMs - recordedAtMs > twoMinutesMs) {
      continue;
    }

    const journey = act.MonitoredVehicleJourney || act.VehicleJourney;
    if (!journey) continue;

    const operator = String(
      journey.OperatorRef || journey.LineRef?.split(':')[0] || ''
    ).trim();

    if (
      approvedOperators.length > 0 &&
      !approvedOperators.includes(operator.toUpperCase())
    ) {
      continue;
    }

    const location = journey.VehicleLocation;
    const lat = parseFloat(location?.Latitude);
    const lng = parseFloat(location?.Longitude);

    if (!isWithinCardiff(lat, lng)) {
      continue;
    }

    const lineName = String(
      journey.PublishedLineName || journey.LineRef || ''
    ).trim();
    const vehicleId = String(
      journey.VehicleRef || journey.FramedVehicleJourneyRef?.DatedVehicleJourneyRef || ''
    ).trim();
    const destination = String(
      journey.DestinationName || journey.DirectionName || 'Cardiff'
    ).trim();
    const bearing = parseFloat(journey.Bearing || 0);

    const delayRaw = journey.Delay;
    const delayMinutes = Math.round(parseIsoDurationToMinutes(delayRaw));

    vehicles.push({
      vehicleId: vehicleId || `BUS-${vehicles.length + 1}`,
      route: lineName,
      destination: destination,
      latitude: lat,
      longitude: lng,
      bearing: isNaN(bearing) ? 0 : bearing,
      delayMinutes: isNaN(delayMinutes) ? 0 : delayMinutes,
      recordedAt: recordedAt.toISOString(),
      operator: operator || 'Cardiff Bus',
    });
  }

  return vehicles;
}

/**
 * Parses GTFS-Realtime binary Protobuf or JSON feed into normalized vehicle array.
 */
function parseGtfsRealtime(bufferOrJson, approvedOperators) {
  let feed;
  if (Buffer.isBuffer(bufferOrJson)) {
    feed = GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(bufferOrJson);
  } else {
    feed = bufferOrJson;
  }

  const nowMs = Date.now();
  const twoMinutesMs = 2 * 60 * 1000;
  const vehicles = [];

  for (const entity of feed.entity || []) {
    const vehicle = entity.vehicle;
    if (!vehicle) continue;

    const timestampSec = vehicle.timestamp ? Number(vehicle.timestamp) : Math.floor(nowMs / 1000);
    const recordedAtMs = timestampSec * 1000;

    if (nowMs - recordedAtMs > twoMinutesMs) {
      continue;
    }

    const pos = vehicle.position;
    if (!pos) continue;

    const lat = Number(pos.latitude);
    const lng = Number(pos.longitude);

    if (!isWithinCardiff(lat, lng)) {
      continue;
    }

    const operator = String(vehicle.vehicle?.agencyId || '').trim();
    if (
      approvedOperators.length > 0 &&
      operator &&
      !approvedOperators.includes(operator.toUpperCase())
    ) {
      continue;
    }

    vehicles.push({
      vehicleId: String(vehicle.vehicle?.id || vehicle.vehicle?.label || entity.id),
      route: String(vehicle.trip?.routeId || ''),
      destination: String(vehicle.trip?.tripId || 'Cardiff'),
      latitude: lat,
      longitude: lng,
      bearing: Number(pos.bearing || 0),
      delayMinutes: 0,
      recordedAt: new Date(recordedAtMs).toISOString(),
      operator: operator || 'Cardiff Bus',
    });
  }

  return vehicles;
}

/**
 * Safely constructs the live datafeed URL.
 * When baseUrl contains data.bus-data.dft.gov.uk, appends api_key query parameter.
 * Also appends Cardiff boundingBox if no query parameters are supplied, satisfying BODS requirements.
 */
function buildFeedUrl(baseUrl, apiKey, routeFilter, approvedOperators) {
  if (!baseUrl) return '';
  if (baseUrl.includes('data.bus-data.dft.gov.uk')) {
    const urlObj = new URL(baseUrl);
    if (apiKey) {
      urlObj.searchParams.set('api_key', apiKey);
    }
    if (routeFilter) {
      urlObj.searchParams.set('lineRef', routeFilter);
    }
    if (approvedOperators && approvedOperators.length > 0) {
      urlObj.searchParams.set('operatorRef', approvedOperators.join(','));
    }
    if (!urlObj.searchParams.has('boundingBox')) {
      urlObj.searchParams.set('boundingBox', '-3.38,51.38,-3.02,51.6');
    }
    return urlObj.toString();
  }
  return baseUrl;
}

/**
 * Controller endpoint: GET /api/live-buses?route=X
 */
exports.getLiveBuses = async (req, res) => {
  try {
    const routeFilter = req.query.route ? String(req.query.route).trim().toUpperCase() : null;

    // Check cache
    const now = Date.now();
    if (cachedData && now - cachedData.timestamp < CACHE_TTL_MS) {
      let vehicles = cachedData.responsePayload.vehicles;
      if (routeFilter) {
        vehicles = vehicles.filter(
          (v) => v.route.toUpperCase() === routeFilter
        );
      }
      return res.json({
        updatedAt: cachedData.responsePayload.updatedAt,
        vehicles,
      });
    }

    const baseUrl = process.env.TRANSPORT_PROVIDER_BASE_URL;
    const apiKey = process.env.TRANSPORT_PROVIDER_API_KEY;
    const feedFormat = (process.env.TRANSPORT_FEED_FORMAT || 'SIRI_VM').toUpperCase();
    const approvedOperatorsStr = process.env.TRANSPORT_OPERATOR_IDS || '';
    const approvedOperators = approvedOperatorsStr
      ? approvedOperatorsStr.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean)
      : [];

    // If provider URL is not configured, return truthful unavailable response
    if (!baseUrl) {
      return res.status(503).json({
        error: 'Live bus data is currently unavailable. Please try again later.',
        code: 'PROVIDER_UNCONFIGURED',
        updatedAt: new Date().toISOString(),
        vehicles: [],
      });
    }

    // Prepare headers and URL
    const headers = {};
    const targetUrl = buildFeedUrl(baseUrl, apiKey, routeFilter, approvedOperators);

    if (!baseUrl.includes('data.bus-data.dft.gov.uk') && apiKey) {
      headers['ApiKey'] = apiKey;
      headers['Authorization'] = `Bearer ${apiKey}`;
    }

    // Fetch feed from provider with a strict 10-second timeout.
    // AbortController prevents queued Node.js requests from piling up
    // if BODS experiences latency spikes.
    const abortController = new AbortController();
    const timeoutId = setTimeout(() => abortController.abort(), 10_000);
    let fetchResponse;
    try {
      fetchResponse = await fetch(targetUrl, {
        headers,
        signal: abortController.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }
    if (!fetchResponse.ok) {
      return res.status(503).json({
        error: 'Live bus data is currently unavailable. Please try again later.',
        code: 'PROVIDER_ERROR',
        updatedAt: new Date().toISOString(),
        vehicles: [],
      });
    }

    let parsedVehicles = [];
    if (feedFormat === 'GTFS_RT') {
      const buffer = Buffer.from(await fetchResponse.arrayBuffer());
      parsedVehicles = parseGtfsRealtime(buffer, approvedOperators);
    } else {
      const xmlText = await fetchResponse.text();
      parsedVehicles = parseSiriVmXml(xmlText, approvedOperators);
    }

    const responsePayload = {
      updatedAt: new Date().toISOString(),
      vehicles: parsedVehicles,
    };

    // Update cache
    cachedData = {
      timestamp: now,
      responsePayload,
    };

    let resultVehicles = parsedVehicles;
    if (routeFilter) {
      resultVehicles = resultVehicles.filter(
        (v) => v.route.toUpperCase() === routeFilter
      );
    }

    return res.json({
      updatedAt: responsePayload.updatedAt,
      vehicles: resultVehicles,
    });
  } catch (err) {
    console.error('Error fetching live bus data:', err.message);
    return res.status(503).json({
      error: 'Live bus data is currently unavailable. Please try again later.',
      code: 'FETCH_FAILED',
      updatedAt: new Date().toISOString(),
      vehicles: [],
    });
  }
};

// In-memory cache for trip updates
let cachedTripUpdates = null;

/**
 * Parses GTFS-Realtime TripUpdates protobuf/JSON into normalized trip updates array.
 */
function parseGtfsRtTripUpdates(bufferOrJson) {
  let feed;
  if (Buffer.isBuffer(bufferOrJson)) {
    feed = GtfsRealtimeBindings.transit_realtime.FeedMessage.decode(bufferOrJson);
  } else {
    feed = bufferOrJson;
  }

  const tripUpdates = [];
  for (const entity of feed.entity || []) {
    const tu = entity.tripUpdate;
    if (!tu) continue;

    const tripId = String(tu.trip?.tripId || entity.id || '').trim();
    const routeId = String(tu.trip?.routeId || '').trim();

    const stopTimeUpdates = [];
    for (const stu of tu.stopTimeUpdate || []) {
      const stopId = String(stu.stopId || '').trim();
      const stopSequence = stu.stopSequence != null ? Number(stu.stopSequence) : null;
      const arrivalDelay = stu.arrival?.delay != null ? Number(stu.arrival.delay) : null;
      const arrivalTime = stu.arrival?.time ? Number(stu.arrival.time) : null;
      const departureDelay = stu.departure?.delay != null ? Number(stu.departure.delay) : null;
      const departureTime = stu.departure?.time ? Number(stu.departure.time) : null;

      stopTimeUpdates.push({
        stopId,
        stopSequence,
        arrivalDelaySeconds: arrivalDelay,
        arrivalTime: arrivalTime,
        departureDelaySeconds: departureDelay,
        departureTime: departureTime,
      });
    }

    const overallDelay = tu.delay != null ? Number(tu.delay) : null;
    const timestampSec = tu.timestamp ? Number(tu.timestamp) : null;

    tripUpdates.push({
      tripId,
      routeId,
      delaySeconds: overallDelay,
      timestamp: timestampSec ? new Date(timestampSec * 1000).toISOString() : null,
      stopTimeUpdates,
    });
  }

  return tripUpdates;
}

/**
 * Controller endpoint: GET /api/trip-updates?route=X
 * Fetches real-time GTFS-RT Trip Updates from BODS API.
 */
exports.getTripUpdates = async (req, res) => {
  try {
    const routeFilter = req.query.route ? String(req.query.route).trim().toUpperCase() : null;

    // Check cache
    const now = Date.now();
    if (cachedTripUpdates && now - cachedTripUpdates.timestamp < CACHE_TTL_MS) {
      let updates = cachedTripUpdates.responsePayload.tripUpdates;
      if (routeFilter) {
        updates = updates.filter(
          (u) => u.routeId && u.routeId.toUpperCase() === routeFilter
        );
      }
      return res.json({
        updatedAt: cachedTripUpdates.responsePayload.updatedAt,
        tripUpdates: updates,
      });
    }

    const apiKey = process.env.TRANSPORT_PROVIDER_API_KEY || process.env.BODS_API_KEY;
    const approvedOperatorsStr = process.env.TRANSPORT_OPERATOR_IDS || 'FCYM,CBUS,STWS,SSWL';
    const approvedOperators = approvedOperatorsStr
      ? approvedOperatorsStr.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean)
      : ['FCYM'];

    const targetUrl = new URL('https://data.bus-data.dft.gov.uk/api/v1/gtfsrt/tripupdates/');
    if (apiKey) {
      targetUrl.searchParams.set('api_key', apiKey);
    }
    if (approvedOperators.length > 0) {
      targetUrl.searchParams.set('operatorRef', approvedOperators.join(','));
    }

    const abortController = new AbortController();
    const timeoutId = setTimeout(() => abortController.abort(), 10000);
    let fetchResponse;
    try {
      fetchResponse = await fetch(targetUrl.toString(), {
        headers: {
          'Accept': 'application/x-protobuf, application/octet-stream, */*',
          'User-Agent': 'BusAlert/1.0',
        },
        signal: abortController.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    if (!fetchResponse.ok) {
      return res.status(503).json({
        error: 'GTFS-RT trip updates are currently unavailable.',
        code: 'PROVIDER_ERROR',
        updatedAt: new Date().toISOString(),
        tripUpdates: [],
      });
    }

    const buffer = Buffer.from(await fetchResponse.arrayBuffer());
    const parsedUpdates = parseGtfsRtTripUpdates(buffer);

    const responsePayload = {
      updatedAt: new Date().toISOString(),
      tripUpdates: parsedUpdates,
    };

    // Update cache
    cachedTripUpdates = {
      timestamp: now,
      responsePayload,
    };

    let resultUpdates = parsedUpdates;
    if (routeFilter) {
      resultUpdates = resultUpdates.filter(
        (u) => u.routeId && u.routeId.toUpperCase() === routeFilter
      );
    }

    return res.json({
      updatedAt: responsePayload.updatedAt,
      tripUpdates: resultUpdates,
    });
  } catch (err) {
    console.error('Error fetching GTFS-RT trip updates:', err.message);
    return res.status(503).json({
      error: 'GTFS-RT trip updates are currently unavailable.',
      code: 'FETCH_FAILED',
      updatedAt: new Date().toISOString(),
      tripUpdates: [],
    });
  }
};

// Export helper methods for testing
exports._parseSiriVmXml = parseSiriVmXml;
exports._parseGtfsRealtime = parseGtfsRealtime;
exports._parseGtfsRtTripUpdates = parseGtfsRtTripUpdates;
exports._isWithinCardiff = isWithinCardiff;
exports._parseIsoDurationToMinutes = parseIsoDurationToMinutes;
exports._buildFeedUrl = buildFeedUrl;

