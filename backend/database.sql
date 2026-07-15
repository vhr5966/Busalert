-- ============================================================================
-- BusAlert Cardiff — PostgreSQL Database Schema
--
-- Tables:
--   users          - Registered app users
--   bus_stops      - Known Cardiff Bus stops with GPS coordinates
--   journeys       - Recorded bus journeys (crowdsourced data)
--
-- Indexes:
--   idx_journeys_prediction - Composite index on (stop_id, bus_line, time)
--     to speed up the delay prediction queries which filter on these columns.
--
-- The prediction algorithm (implemented in the backend controller) queries
-- the journeys table using these indexed columns and computes a weighted
-- moving average of journey durations.
-- ============================================================================

-- ── Users Table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,  -- bcrypt hash
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ── Bus Stops Table ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bus_stops (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed data for Cardiff Bus stops (city centre and surrounding areas).
-- These are the same stops defined in lib/core/constants.dart for the app.
INSERT INTO bus_stops (id, name, latitude, longitude) VALUES
    (1,  'Cardiff Central Station',     51.4757, -3.1791),
    (2,  'Westgate Street (Stop WJ)',   51.4778, -3.1789),
    (3,  'Castle Street (Stop CK)',     51.4813, -3.1805),
    (4,  'Queen Street (Stop QY)',      51.4817, -3.1705),
    (5,  'Cathays Station',             51.4881, -3.1884),
    (6,  'University of Cardiff',       51.4837, -3.1807),
    (7,  'Heath Hospital',              51.5177, -3.1817),
    (8,  'City Road (Stop CP)',         51.4875, -3.1625),
    (9,  'Canton (Cowbridge Road)',     51.4795, -3.2030),
    (10, 'Cardiff Bay',                 51.4647, -3.1650)
ON CONFLICT (id) DO NOTHING;

-- ── Journeys Table ───────────────────────────────────────────────────────
-- Records a single bus journey from boarding to alighting.
CREATE TABLE IF NOT EXISTS journeys (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    board_stop_id       INTEGER NOT NULL REFERENCES bus_stops(id),
    board_stop_name     VARCHAR(200) NOT NULL,
    board_lat           DOUBLE PRECISION NOT NULL,
    board_lng           DOUBLE PRECISION NOT NULL,
    alight_stop_id      INTEGER REFERENCES bus_stops(id),
    alight_stop_name    VARCHAR(200),
    alight_lat          DOUBLE PRECISION,
    alight_lng          DOUBLE PRECISION,
    bus_line            VARCHAR(20) NOT NULL,
    boarding_time       TIMESTAMP WITH TIME ZONE NOT NULL,
    alighting_time      TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure we don't duplicate identical journey submissions
    CONSTRAINT unique_journey UNIQUE (user_id, boarding_time, bus_line, board_stop_id)
);

-- ── Indexes for Performance ──────────────────────────────────────────────

-- Primary index for delay prediction queries.
-- The prediction endpoint filters by (bus_stop, bus_line, time_of_day).
-- We also include day-of-week since delays vary by weekday vs weekend.
CREATE INDEX idx_journeys_prediction
    ON journeys (board_stop_id, bus_line, boarding_time);

-- Index for fetching a user's journey history.
CREATE INDEX idx_journeys_user_id
    ON journeys (user_id, boarding_time DESC);

-- Index for looking up bus stops by proximity (GPS queries).
CREATE INDEX idx_bus_stops_location
    ON bus_stops (latitude, longitude);
