// ============================================================================
// Unit Tests for Live Buses Backend Controller & Parsers
// ============================================================================

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  _parseSiriVmXml,
  _parseGtfsRealtime,
  _isWithinCardiff,
  _parseIsoDurationToMinutes,
  _buildFeedUrl,
} = require('../src/controllers/liveBusesController');

test('BODS Datafeed URL Construction', () => {
  const baseUrl = 'https://data.bus-data.dft.gov.uk/api/v1/datafeed/';
  const mockKey = 'dummy_test_key_123';
  const constructed = _buildFeedUrl(baseUrl, mockKey);

  assert.ok(constructed.includes('api_key=dummy_test_key_123'));
  assert.ok(constructed.includes('boundingBox=-3.38%2C51.38%2C-3.02%2C51.6'));

  // Test non-BODS URL passes through without appending query param
  const otherUrl = 'https://example.com/api/siri';
  assert.equal(_buildFeedUrl(otherUrl, mockKey), 'https://example.com/api/siri');

  // Test empty URL
  assert.equal(_buildFeedUrl('', mockKey), '');
});

test('ISO 8601 Duration Parser', () => {
  assert.equal(_parseIsoDurationToMinutes('PT2M'), 2);
  assert.equal(_parseIsoDurationToMinutes('PT5M30S'), 5.5);
  assert.equal(_parseIsoDurationToMinutes('-PT1M'), -1);
  assert.equal(_parseIsoDurationToMinutes('PT0S'), 0);
  assert.equal(_parseIsoDurationToMinutes(null), 0);
});

test('Cardiff Bounds Validation', () => {
  assert.equal(_isWithinCardiff(51.48, -3.18), true);  // Cardiff Central
  assert.equal(_isWithinCardiff(51.58, -3.20), true);  // North Cardiff
  assert.equal(_isWithinCardiff(51.45, -3.15), true);  // Cardiff Bay
  assert.equal(_isWithinCardiff(51.75, -3.40), false); // Merthyr Tydfil (outside)
  assert.equal(_isWithinCardiff(53.48, -2.24), false); // Manchester (outside)
  assert.equal(_isWithinCardiff(0, 0), false);         // Null Island
});

test('SIRI-VM XML Parsing with Cardiff & Stale Filters', () => {
  const nowIso = new Date().toISOString();
  const oldIso = new Date(Date.now() - 5 * 60 * 1000).toISOString(); // 5 mins ago (stale)

  const xmlSample = `<?xml version="1.0" encoding="UTF-8"?>
  <Siri xmlns="http://www.siri.org.uk/siri" version="2.0">
    <ServiceDelivery>
      <VehicleMonitoringDelivery>
        <VehicleActivity>
          <RecordedAtTime>${nowIso}</RecordedAtTime>
          <MonitoredVehicleJourney>
            <LineRef>CBUS:27</LineRef>
            <PublishedLineName>27</PublishedLineName>
            <OperatorRef>CBUS</OperatorRef>
            <VehicleRef>BUS-101</VehicleRef>
            <DestinationName>Thornhill</DestinationName>
            <VehicleLocation>
              <Latitude>51.4815</Latitude>
              <Longitude>-3.1791</Longitude>
            </VehicleLocation>
            <Bearing>180</Bearing>
            <Delay>PT3M</Delay>
          </MonitoredVehicleJourney>
        </VehicleActivity>
        <!-- Stale Vehicle (> 2 mins old) -->
        <VehicleActivity>
          <RecordedAtTime>${oldIso}</RecordedAtTime>
          <MonitoredVehicleJourney>
            <LineRef>CBUS:57</LineRef>
            <PublishedLineName>57</PublishedLineName>
            <OperatorRef>CBUS</OperatorRef>
            <VehicleRef>BUS-OLD</VehicleRef>
            <VehicleLocation>
              <Latitude>51.5000</Latitude>
              <Longitude>-3.1800</Longitude>
            </VehicleLocation>
          </MonitoredVehicleJourney>
        </VehicleActivity>
        <!-- Outside Cardiff -->
        <VehicleActivity>
          <RecordedAtTime>${nowIso}</RecordedAtTime>
          <MonitoredVehicleJourney>
            <LineRef>STAGE:X4</LineRef>
            <PublishedLineName>X4</PublishedLineName>
            <OperatorRef>STAGE</OperatorRef>
            <VehicleRef>BUS-OUTSIDE</VehicleRef>
            <VehicleLocation>
              <Latitude>53.4800</Latitude>
              <Longitude>-2.2400</Longitude>
            </VehicleLocation>
          </MonitoredVehicleJourney>
        </VehicleActivity>
      </VehicleMonitoringDelivery>
    </ServiceDelivery>
  </Siri>`;

  const vehicles = _parseSiriVmXml(xmlSample, ['CBUS']);
  assert.equal(vehicles.length, 1);
  assert.equal(vehicles[0].vehicleId, 'BUS-101');
  assert.equal(vehicles[0].route, '27');
  assert.equal(vehicles[0].destination, 'Thornhill');
  assert.equal(vehicles[0].latitude, 51.4815);
  assert.equal(vehicles[0].longitude, -3.1791);
  assert.equal(vehicles[0].delayMinutes, 3);
  assert.equal(vehicles[0].operator, 'CBUS');
});
