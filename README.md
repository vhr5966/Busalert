# BusAlert Cardiff — Real Official Transport Data Architecture

A Flutter & Node.js application for real-time Cardiff bus tracking and crowdsourced delay prediction using official UK Department for Transport (BODS SIRI-VM / GTFS-Realtime) and NaPTAN datasets.

---

## 1. Backend Server Setup (`backend/`)

The Node.js backend serves as a secure proxy to fetch, normalize, filter, and cache official transport provider feeds.

### Prerequisites
- Node.js (v18+)
- PostgreSQL (for journey history & delay prediction data)

### Installation & Environment Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   npm install
   ```

2. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

3. Configure provider credentials in `.env`:
   ```env
   PORT=3000
   NODE_ENV=development

   # Database
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=busalert
   DB_USER=postgres
   DB_PASSWORD=your_password

   # Authorized Transport Data Provider (SIRI-VM XML or GTFS-Realtime)
   TRANSPORT_PROVIDER_BASE_URL=https://data.bus-data.dft.gov.uk/api/v1/siri-vm/
   TRANSPORT_PROVIDER_API_KEY=your_secret_bods_api_key
   TRANSPORT_FEED_FORMAT=SIRI_VM
   TRANSPORT_OPERATOR_IDS=CBUS,NAT,STAGE
   ```

4. Run backend unit tests:
   ```bash
   npm test
   ```

5. Start backend server:
   ```bash
   npm start
   ```

---

## 2. Flutter App Setup (`lib/`)

The Flutter application connects to the backend REST API endpoint (`GET /api/live-buses`) to display real-time bus locations in Cardiff.

### Running with `--dart-define`

Pass the public backend URL using `--dart-define=BACKEND_URL=...`:

- **Android Emulator:**
  ```bash
  flutter run -d android --dart-define=BACKEND_URL=http://10.0.2.2:3000
  ```

- **Windows / Desktop / iOS:**
  ```bash
  flutter run -d windows --dart-define=BACKEND_URL=http://localhost:3000
  ```

---

## 3. Data Integrity & Truthful Availability

- **Static Reference Data:** Downloaded NaPTAN Cardiff bus-stop dataset is used for bus-stop markers, stop search, and boarding detection.
- **Real Live Buses Only:** Live buses are fetched exclusively from `/api/live-buses`.
- **Zero Mock Buses:** If no provider credentials are set or the feed is offline, the app displays:
  > *"Live bus data is currently unavailable. Please try again later."*
