// ============================================================================
// Database Connection & Storage Manager
//
// Tries to connect to PostgreSQL via `pg.Pool`.
// If PostgreSQL is offline / not installed on this machine, automatically
// falls back to a persistent JSON store (`backend/data/local_db.json`)
// so account registration, authentication, journeys, and delay predictions
// function immediately without setup errors.
// ============================================================================

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const DATA_DIR = path.join(__dirname, '../../data');
const DB_FILE = path.join(DATA_DIR, 'local_db.json');

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

function loadLocalData() {
  if (fs.existsSync(DB_FILE)) {
    try {
      return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    } catch (e) {}
  }
  return { users: [], journeys: [], bus_stops: [] };
}

function saveLocalData(data) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (e) {
    console.error('Error writing local database file:', e);
  }
}

let isPgConnected = false;

const pgPool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  database: process.env.DB_NAME || 'busalert',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 3000,
});

pgPool.query('SELECT NOW()')
  .then(() => {
    isPgConnected = true;
    console.log('✅ Connected to PostgreSQL database successfully');
  })
  .catch((err) => {
    isPgConnected = false;
    console.warn(`⚠️ PostgreSQL unavailable (${err.message}) — using persistent local database fallback (${DB_FILE})`);
  });

/**
 * Executes a query against PostgreSQL if available, or local JSON fallback.
 */
async function query(text, params = []) {
  if (isPgConnected) {
    try {
      return await pgPool.query(text, params);
    } catch (pgError) {
      console.warn('⚠️ PostgreSQL query failed, falling back to local storage:', pgError.message);
    }
  }

  // Fallback local query handler
  const data = loadLocalData();
  const normalizedSql = text.trim().toLowerCase();

  // 1. Users Queries
  if (normalizedSql.includes('from users') || normalizedSql.includes('into users')) {
    if (normalizedSql.startsWith('select id from users where email')) {
      const email = (params[0] || '').toLowerCase().trim();
      const match = data.users.find(u => u.email.toLowerCase() === email);
      return { rows: match ? [{ id: match.id }] : [], rowCount: match ? 1 : 0 };
    }

    if (normalizedSql.startsWith('select id, name, email, password from users where email')) {
      const email = (params[0] || '').toLowerCase().trim();
      const match = data.users.find(u => u.email.toLowerCase() === email);
      return { rows: match ? [match] : [], rowCount: match ? 1 : 0 };
    }

    if (normalizedSql.startsWith('insert into users')) {
      const [name, email, password] = params;
      const newId = data.users.length > 0 ? Math.max(...data.users.map(u => u.id || 0)) + 1 : 1;
      const newUser = {
        id: newId,
        name: (name || '').trim(),
        email: (email || '').toLowerCase().trim(),
        password,
        created_at: new Date().toISOString(),
      };
      data.users.push(newUser);
      saveLocalData(data);
      return {
        rows: [{
          id: newUser.id,
          name: newUser.name,
          email: newUser.email,
          created_at: newUser.created_at,
        }],
        rowCount: 1,
      };
    }
  }

  // 2. Journeys Queries
  if (normalizedSql.includes('from journeys') || normalizedSql.includes('into journeys')) {
    if (normalizedSql.startsWith('insert into journeys')) {
      const [
        userId, boardStopId, boardStopName, boardLat, boardLng,
        alightStopId, alightStopName, alightLat, alightLng,
        busLine, boardingTime, alightingTime,
      ] = params;

      const newId = data.journeys.length > 0 ? Math.max(...data.journeys.map(j => j.id || 0)) + 1 : 1;
      const newJourney = {
        id: newId,
        user_id: userId,
        board_stop_id: boardStopId,
        board_stop_name: boardStopName,
        board_lat: boardLat,
        board_lng: boardLng,
        alight_stop_id: alightStopId,
        alight_stop_name: alightStopName,
        alight_lat: alightLat,
        alight_lng: alightLng,
        bus_line: busLine,
        boarding_time: boardingTime,
        alighting_time: alightingTime,
      };

      data.journeys.unshift(newJourney);
      saveLocalData(data);
      return { rows: [{ id: newJourney.id }], rowCount: 1 };
    }

    if (normalizedSql.includes('where user_id = $1')) {
      const userId = params[0];
      const userJourneys = data.journeys.filter(j => j.user_id === userId);
      return { rows: userJourneys.slice(0, 100), rowCount: userJourneys.length };
    }

    if (normalizedSql.includes('board_stop_id') && normalizedSql.includes('bus_line')) {
      const [stopId, busLine] = params;
      const matched = data.journeys.filter(j =>
        String(j.board_stop_id) === String(stopId) &&
        String(j.bus_line) === String(busLine)
      );
      return { rows: matched, rowCount: matched.length };
    }
  }

  // 3. Bus Stops
  if (normalizedSql.includes('from bus_stops')) {
    return { rows: data.bus_stops || [], rowCount: (data.bus_stops || []).length };
  }

  // Default empty result
  return { rows: [], rowCount: 0 };
}

module.exports = {
  query,
};
