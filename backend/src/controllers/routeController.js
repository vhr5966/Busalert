// ============================================================================
// Route Controller — BODS Timetables API Integration
//
// Fetches official route data from BODS Timetables API (/api/v1/dataset).
// The BODS API returns dataset metadata including a 'lines' array per dataset.
// These are expanded into individual route objects and served as JSON.
//
// Data source priority:
//   1. BODS Timetables API (live, Cardiff adminArea=571)
//   2. Locally configured TRANSPORT_ROUTE_FEED_URL (TransXChange/JSON)
//   3. 503 error (handled by RouteRepository fallback to reference dataset)
//
// API key auth: BODS uses ?api_key= query parameter (not a Bearer header).
// ============================================================================

const { XMLParser } = require('fast-xml-parser');

// In-memory route cache
let cachedRoutesData = null; // { timestamp: number, responsePayload: object }
const ROUTE_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

// BODS Timetables API base URL
const BODS_API_BASE = 'https://data.bus-data.dft.gov.uk/api/v1/dataset/';

// Cardiff ATCO area code
const CARDIFF_ADMIN_AREA = '571';

// Operator name lookup by NOC code (common Welsh operators)
const NOC_OPERATOR_NAMES = {
  FCYM: 'First Cymru (Cardiff)',
  FABD: 'First Aberdeen',
  FBRI: 'First Bristol',
  STWS: 'Stagecoach South Wales',
  SSWL: 'Stagecoach South Wales',
  SCGL: 'Stagecoach Gloucestershire',
  CBUS: 'Cardiff Bus (Bws Caerdydd)',
  NAT:  'National Express',
};
// Welsh/Cardiff NOC codes to prefer when resolving operator for Cardiff datasets
const PREFERRED_WELSH_NOCS = ['CBUS', 'FCYM', 'STWS', 'SSWL'];

/**
 * Maps BODS dataset result to individual route objects.
 * Each line number in dataset.lines becomes one route entry.
 *
 * Prefers Welsh NOC codes (FCYM, STWS) over UK-wide ones (FABD, FBRI)
 * so Cardiff datasets are correctly attributed.
 */
function expandDatasetToRoutes(dataset) {
  const lines = Array.isArray(dataset.lines) ? dataset.lines : [];
  const operatorName = dataset.operatorName || 'Cardiff Area Operator';
  const nocs = Array.isArray(dataset.noc) ? dataset.noc : [];

  // Prefer Welsh NOC codes first
  let bestNoc = null;
  let resolvedOperatorName = operatorName;

  for (const preferred of PREFERRED_WELSH_NOCS) {
    if (nocs.map((n) => n.toUpperCase()).includes(preferred)) {
      bestNoc = preferred;
      resolvedOperatorName = NOC_OPERATOR_NAMES[preferred] || operatorName;
      break;
    }
  }

  // Fallback: first NOC that has a name in our lookup
  if (!bestNoc) {
    for (const noc of nocs) {
      if (NOC_OPERATOR_NAMES[noc.toUpperCase()]) {
        bestNoc = noc.toUpperCase();
        resolvedOperatorName = NOC_OPERATOR_NAMES[bestNoc];
        break;
      }
    }
  }

  const primaryNoc = bestNoc || (nocs.length > 0 ? nocs[0] : 'UNKNOWN');
  const datasetId = String(dataset.id || '');
  const description = dataset.description || '';

  return lines.map((line) => ({
    id: `bods-${datasetId}-${line}`,
    number: String(line).trim(),
    name: description ? `${description} – Route ${line}` : `Route ${line}`,
    operatorId: primaryNoc,
    operatorName: resolvedOperatorName,
    isActive: dataset.status === 'published',
  }));
}

/**
 * Fetches Cardiff routes from the BODS Timetables API.
 * Paginates through all results for adminArea=571.
 */
async function fetchBodsCardiffRoutes(apiKey) {
  const allRoutes = [];
  let url = `${BODS_API_BASE}?api_key=${encodeURIComponent(apiKey)}&adminArea=${CARDIFF_ADMIN_AREA}&status=published&limit=25`;

  while (url) {
    const response = await fetch(url, {
      headers: { 'Accept': 'application/json', 'User-Agent': 'BusAlert/1.0' },
    });

    if (!response.ok) {
      console.error(`BODS API error: HTTP ${response.status}`);
      break;
    }

    const body = await response.json();
    const results = Array.isArray(body.results) ? body.results : [];

    for (const dataset of results) {
      const routes = expandDatasetToRoutes(dataset);
      allRoutes.push(...routes);
    }

    // Follow pagination
    url = body.next || null;
  }

  // De-duplicate by route number (keep first occurrence)
  const seen = new Set();
  return allRoutes.filter((r) => {
    if (seen.has(r.number)) return false;
    seen.add(r.number);
    return true;
  });
}

/**
 * Parses SIRI / TransXChange XML route structure.
 */
function parseTransXChangeRoutes(xmlText, approvedOperators) {
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
    removeNSPrefix: true,
  });

  const parsed = parser.parse(xmlText);
  const tx = parsed.TransXChange || parsed;
  const servicesRaw = tx.Services?.Service;
  if (!servicesRaw) return [];

  const services = Array.isArray(servicesRaw) ? servicesRaw : [servicesRaw];
  const routes = [];

  for (const svc of services) {
    const operatorRef = String(svc.RegisteredOperatorRef || svc.OperatorRef || '').trim();
    if (
      approvedOperators.length > 0 &&
      operatorRef &&
      !approvedOperators.includes(operatorRef.toUpperCase())
    ) {
      continue;
    }

    const serviceCode = String(svc.ServiceCode || svc.LineName || '').trim();
    const linesRaw = svc.Lines?.Line;
    const lines = Array.isArray(linesRaw) ? linesRaw : linesRaw ? [linesRaw] : [];

    for (const line of lines) {
      const lineName = String(line.LineName || line['@_id'] || serviceCode).trim();
      const description = String(
        svc.Description || svc.StandardService?.Origin || 'Cardiff Route'
      ).trim();

      routes.push({
        id: String(line['@_id'] || `${operatorRef}-${lineName}`),
        number: lineName,
        name: description,
        operatorId: operatorRef || 'cardiff-bus',
        operatorName: NOC_OPERATOR_NAMES[operatorRef.toUpperCase()] || operatorRef || 'Cardiff Bus',
        isActive: true,
      });
    }
  }

  return routes;
}

/**
 * Normalizes array of route objects or JSON payload.
 */
function normalizeRouteArray(rawRoutes, approvedOperators) {
  if (!Array.isArray(rawRoutes)) return [];

  const routes = [];
  for (const r of rawRoutes) {
    const routeNum = String(r.number || r.route_short_name || r.lineRef || r.line || '').trim();
    if (!routeNum) continue;

    const opId = String(r.operatorId || r.agency_id || r.operatorRef || 'cardiff-bus').trim();
    if (
      approvedOperators.length > 0 &&
      !approvedOperators.includes(opId.toUpperCase())
    ) {
      continue;
    }

    routes.push({
      id: String(r.id || r.route_id || `${opId}-${routeNum}`),
      number: routeNum,
      name: String(r.name || r.route_long_name || r.destination || `Route ${routeNum}`).trim(),
      operatorId: opId,
      operatorName: String(r.operatorName || r.agency_name || NOC_OPERATOR_NAMES[opId.toUpperCase()] || 'Cardiff Bus').trim(),
      isActive: r.isActive !== undefined ? Boolean(r.isActive) : true,
    });
  }

  return routes;
}

/**
 * Controller endpoint: GET /api/routes?operator=X&activeOnly=true
 */
exports.getRoutes = async (req, res) => {
  try {
    const operatorFilter = req.query.operator ? String(req.query.operator).trim().toUpperCase() : null;
    const activeOnly = req.query.activeOnly !== 'false';

    const now = Date.now();
    if (cachedRoutesData && now - cachedRoutesData.timestamp < ROUTE_CACHE_TTL_MS) {
      let result = cachedRoutesData.responsePayload.routes;
      if (operatorFilter) {
        result = result.filter((r) => r.operatorId.toUpperCase() === operatorFilter);
      }
      if (activeOnly) {
        result = result.filter((r) => r.isActive);
      }
      return res.json({
        source: cachedRoutesData.responsePayload.source,
        updatedAt: cachedRoutesData.responsePayload.updatedAt,
        routes: result,
      });
    }

    const bodsApiKey = process.env.BODS_API_KEY;
    const customFeedUrl = process.env.TRANSPORT_ROUTE_FEED_URL;
    const approvedOperatorsStr = process.env.TRANSPORT_OPERATOR_IDS || '';
    const approvedOperators = approvedOperatorsStr
      ? approvedOperatorsStr.split(',').map((s) => s.trim().toUpperCase())
      : [];

    let parsedRoutes = [];
    let source = 'unknown';

    // ── Priority 1: BODS Timetables API ──────────────────────────────────
    if (bodsApiKey) {
      try {
        console.log('🚌 Fetching routes from BODS Timetables API (Cardiff adminArea=571)…');
        parsedRoutes = await fetchBodsCardiffRoutes(bodsApiKey);
        source = 'BODS Timetables API';
        console.log(`🚌 BODS returned ${parsedRoutes.length} route entries for Cardiff`);
      } catch (bodsErr) {
        console.error('🚌 BODS API fetch failed:', bodsErr.message);
        parsedRoutes = [];
      }
    }

    // ── Priority 2: Custom TransXChange/JSON feed ─────────────────────────
    if (parsedRoutes.length === 0 && customFeedUrl) {
      try {
        console.log(`🚌 Falling back to custom feed: ${customFeedUrl}`);
        const feedHeaders = {};
        const feedApiKey = process.env.TRANSPORT_PROVIDER_API_KEY;
        if (feedApiKey) {
          feedHeaders['Authorization'] = `Bearer ${feedApiKey}`;
        }

        const fetchResponse = await fetch(customFeedUrl, { headers: feedHeaders });
        if (fetchResponse.ok) {
          const contentType = fetchResponse.headers.get('content-type') || '';
          if (contentType.includes('xml') || customFeedUrl.endsWith('.xml')) {
            const xmlText = await fetchResponse.text();
            parsedRoutes = parseTransXChangeRoutes(xmlText, approvedOperators);
          } else {
            const jsonBody = await fetchResponse.json();
            const rawList = Array.isArray(jsonBody) ? jsonBody : jsonBody.routes || jsonBody.data || [];
            parsedRoutes = normalizeRouteArray(rawList, approvedOperators);
          }
          source = 'Custom Feed';
          console.log(`🚌 Custom feed returned ${parsedRoutes.length} routes`);
        }
      } catch (feedErr) {
        console.error('🚌 Custom feed fetch failed:', feedErr.message);
      }
    }

    // ── No live data available ────────────────────────────────────────────
    if (parsedRoutes.length === 0) {
      return res.status(503).json({
        error: 'Route information is currently unavailable.',
        code: 'FEED_UNAVAILABLE',
        updatedAt: new Date().toISOString(),
        routes: [],
      });
    }

    const responsePayload = {
      source,
      updatedAt: new Date().toISOString(),
      routes: parsedRoutes,
    };

    cachedRoutesData = { timestamp: now, responsePayload };

    let result = parsedRoutes;
    if (operatorFilter) {
      result = result.filter((r) => r.operatorId.toUpperCase() === operatorFilter);
    }
    if (activeOnly) {
      result = result.filter((r) => r.isActive);
    }

    return res.json({
      source,
      updatedAt: responsePayload.updatedAt,
      routes: result,
    });
  } catch (err) {
    console.error('Error fetching official routes:', err.message);
    return res.status(503).json({
      error: 'Route information is currently unavailable.',
      code: 'FETCH_FAILED',
      updatedAt: new Date().toISOString(),
      routes: [],
    });
  }
};

// Export helper parsers for unit tests
exports._parseTransXChangeRoutes = parseTransXChangeRoutes;
exports._normalizeRouteArray = normalizeRouteArray;
exports._expandDatasetToRoutes = expandDatasetToRoutes;
exports._fetchBodsCardiffRoutes = fetchBodsCardiffRoutes;
