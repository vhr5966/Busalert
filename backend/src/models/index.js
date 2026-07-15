// ============================================================================
// PostgreSQL Database Connection
//
// Uses the `pg` library to create a connection pool. The pool is configured
// via environment variables (see .env.example). All controllers import this
// pool to execute queries.
//
// The pool manages multiple concurrent connections efficiently and
// automatically reconnects if the database connection drops.
// ============================================================================

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  database: process.env.DB_NAME || 'busalert',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  // Maximum number of clients the pool should contain
  max: 10,
  // How long a client can be idle before being closed
  idleTimeoutMillis: 30000,
  // How long to wait for a connection from the pool
  connectionTimeoutMillis: 5000,
});

// Test the connection on startup
pool.query('SELECT NOW()')
  .then(() => console.log('✅ Connected to PostgreSQL'))
  .catch((err) => console.error('❌ Database connection error:', err.message));

module.exports = pool;
