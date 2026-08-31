// ============================================================================
// Unit Tests for Official Routes Backend Controller & Parsers
// ============================================================================

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  _parseTransXChangeRoutes,
  _normalizeRouteArray,
  _expandDatasetToRoutes,
} = require('../src/controllers/routeController');

test('TransXChange / SIRI XML Route Parser', () => {
  const xmlSample = `<?xml version="1.0" encoding="UTF-8"?>
  <TransXChange xmlns="http://www.transxchange.org.uk/">
    <Services>
      <Service>
        <ServiceCode>CBUS:28</ServiceCode>
        <RegisteredOperatorRef>CBUS</RegisteredOperatorRef>
        <Description>City Centre to Llanishen via Heath</Description>
        <Lines>
          <Line id="L-28">
            <LineName>28</LineName>
          </Line>
        </Lines>
      </Service>
      <Service>
        <ServiceCode>STAGE:X4</ServiceCode>
        <RegisteredOperatorRef>STAGE</RegisteredOperatorRef>
        <Description>Cardiff to Merthyr Tydfil</Description>
        <Lines>
          <Line id="L-X4">
            <LineName>X4</LineName>
          </Line>
        </Lines>
      </Service>
    </Services>
  </TransXChange>`;

  const routes = _parseTransXChangeRoutes(xmlSample, ['CBUS']);
  assert.equal(routes.length, 1);
  assert.equal(routes[0].number, '28');
  assert.equal(routes[0].name, 'City Centre to Llanishen via Heath');
  assert.equal(routes[0].operatorId, 'CBUS');
  assert.equal(routes[0].isActive, true);
});

test('Route JSON Normalization & Operator Filter', () => {
  const rawList = [
    {
      id: 'r-1',
      number: '27',
      name: 'City Centre to Thornhill',
      operatorId: 'CBUS',
      operatorName: 'Cardiff Bus',
      isActive: true,
    },
    {
      id: 'r-2',
      number: '304',
      name: 'Cardiff to Penarth',
      operatorId: 'FCYM',
      operatorName: 'First Cymru',
      isActive: true,
    },
    {
      id: 'r-3',
      number: '999',
      name: 'Invalid Outside Operator',
      operatorId: 'OUTSIDE',
      isActive: true,
    },
  ];

  const normalized = _normalizeRouteArray(rawList, ['CBUS', 'FCYM']);
  assert.equal(normalized.length, 2);
  assert.equal(normalized[0].number, '27');
  assert.equal(normalized[1].number, '304');
  assert.equal(normalized[1].operatorName, 'First Cymru');
});

test('BODS Dataset Expansion — prefers Welsh NOC over UK-wide', () => {
  // Real BODS data has FABD before FCYM in the noc array
  const dataset = {
    id: 8322,
    operatorName: 'First Bus',
    description: 'FCYM-Bridgend',
    noc: ['FABD', 'FYOR', 'FBRA', 'FCYM', 'FGLA'],
    lines: ['303', '304', 'X2', '64'],
    status: 'published',
  };

  const routes = _expandDatasetToRoutes(dataset);

  assert.equal(routes.length, 4);
  assert.equal(routes[0].number, '303');
  assert.equal(routes[0].id, 'bods-8322-303');
  // Must pick FCYM (Welsh) over FABD (Aberdeen)
  assert.equal(routes[0].operatorId, 'FCYM');
  assert.equal(routes[0].operatorName, 'First Cymru (Cardiff)');
  assert.equal(routes[0].isActive, true);
  // Route name should include dataset description
  assert.ok(routes[0].name.includes('FCYM-Bridgend'));

  assert.equal(routes[2].number, 'X2');
  assert.equal(routes[3].number, '64');
});

test('BODS Dataset Expansion — empty lines array', () => {
  const dataset = {
    id: 9999,
    operatorName: 'Test Op',
    noc: ['TEST'],
    lines: [],
    status: 'published',
  };

  const routes = _expandDatasetToRoutes(dataset);
  assert.equal(routes.length, 0);
});

test('BODS Dataset Expansion — inactive dataset', () => {
  const dataset = {
    id: 1234,
    operatorName: 'Old Operator',
    noc: ['STWS'],
    lines: ['99'],
    status: 'inactive',
  };

  const routes = _expandDatasetToRoutes(dataset);
  assert.equal(routes.length, 1);
  assert.equal(routes[0].isActive, false);
  assert.equal(routes[0].operatorName, 'Stagecoach South Wales');
});
