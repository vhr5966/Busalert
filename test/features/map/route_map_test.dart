// ============================================================================
// Unit & State Tests for GTFS Route Map Feature
// ============================================================================

import 'package:busalert/data/models/bods_vehicle.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/repositories/bods_repository.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/features/map/providers/route_map_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Sample GTFS CSV strings for isolated test suite
const kTestRoutesCsv = '''route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_url,route_color,route_text_color
CB:1,CB,1,City Circle,,,3,,A3A3A5,FFFFFF
CB:27,CB,27,City Centre to Thornhill,,,3,,FFFFFF,000000
CB:99,CB,99,No Shape Route,,,3,,FFFFFF,000000''';

const kTestTripsCsv = '''route_id,service_id,trip_id,trip_headsign,trip_short_name,direction_id,block_id,shape_id,wheelchair_accessible,bikes_allowed
CB:1,CB:1:S1,TRIP-1,"City Centre",,1,C01,SHAPE-1,,
CB:27,CB:27:S1,TRIP-27,"Thornhill",,1,C27,SHAPE-27,,
CB:99,CB:99:S1,TRIP-99,"No Shape",,1,C99,,,,''';

const kTestStopsCsv = '''stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon,zone_id,stop_url,location_type,parent_station,stop_timezone,wheelchair_boarding
STOP-1,,"Cardiff Central",,51.4816,-3.1791,,,0,,,0
STOP-2,,"Heath Hospital",,51.5000,-3.1800,,,0,,,0
STOP-3,,"Thornhill",,51.5300,-3.1900,,,0,,,0''';

const kTestStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence,stop_headsign,pickup_type,drop_off_type,timepoint
TRIP-1,08:00:00,08:00:00,STOP-1,1,,0,0,0
TRIP-1,08:15:00,08:15:00,STOP-2,2,,0,0,0
TRIP-27,09:00:00,09:00:00,STOP-1,1,,0,0,0
TRIP-27,09:30:00,09:30:00,STOP-3,2,,0,0,0''';

const kTestShapesCsv = '''shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence,shape_dist_traveled
SHAPE-1,51.4816,-3.1791,1,
SHAPE-1,51.5000,-3.1800,2,
SHAPE-27,51.4816,-3.1791,1,
SHAPE-27,51.5300,-3.1900,2,''';

// Mock BodsRepository for testing live buses toggle
class MockBodsRepository extends BodsRepository {
  final List<BodsVehicle> mockVehicles;
  final bool shouldFail;

  MockBodsRepository({
    this.mockVehicles = const [],
    this.shouldFail = false,
  });

  @override
  Future<List<BodsVehicle>> getAllVehicles() async {
    if (shouldFail) {
      throw Exception('503 Service Unavailable');
    }
    return mockVehicles;
  }
}

void main() {
  group('GTFS Route Map Feature Tests', () {
    late GtfsRepository gtfsRepository;

    setUp(() async {
      gtfsRepository = GtfsRepository();
      await gtfsRepository.loadGtfsData(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );
    });

    // ── Test 1: One selected route ──────────────────────────────────────────
    test('1. One selected route loads shapes and stops correctly', () async {
      final notifier = RouteMapNotifier(gtfsRepository: gtfsRepository);
      await notifier.initGtfs(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );

      notifier.toggleRouteSelection('1');

      final state = notifier.state;
      expect(state.selectedRouteNumbers, contains('1'));
      expect(state.routePolylines.containsKey('1'), isTrue);
      expect(state.routePolylines['1']!.first.length, equals(2));
      expect(state.routeStops.containsKey('1'), isTrue);
      expect(state.routeStops['1']!.length, equals(2));
      expect(state.routeStops['1']![0].name, equals('Cardiff Central'));
      expect(state.routeStops['1']![1].name, equals('Heath Hospital'));
      expect(state.unavailableRouteShapes, isEmpty);
    });

    // ── Test 2: Multiple selected routes ────────────────────────────────────
    test('2. Multiple selected routes get distinct colors and shapes', () async {
      final notifier = RouteMapNotifier(gtfsRepository: gtfsRepository);
      await notifier.initGtfs(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );

      notifier.toggleRouteSelection('1');
      notifier.toggleRouteSelection('27');

      final state = notifier.state;
      expect(state.selectedRouteNumbers, equals({'1', '27'}));
      expect(state.routePolylines.length, equals(2));
      expect(state.routeColors.length, equals(2));
      // Colors must be distinct
      expect(state.routeColors['1'], isNot(equals(state.routeColors['27'])));

      // Route 99 has no shape data
      notifier.toggleRouteSelection('99');
      expect(notifier.state.unavailableRouteShapes, contains('99'));
    });

    // ── Test 3: Clear selection ─────────────────────────────────────────────
    test('3. Clear selection resets shapes and preserves all stops', () async {
      final notifier = RouteMapNotifier(gtfsRepository: gtfsRepository);
      await notifier.initGtfs(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );

      notifier.toggleRouteSelection('1');
      notifier.toggleRouteSelection('27');
      expect(notifier.state.selectedRouteNumbers.length, equals(2));

      notifier.clearSelection();

      final state = notifier.state;
      expect(state.selectedRouteNumbers, isEmpty);
      expect(state.routePolylines, isEmpty);
      expect(state.routeStops, isEmpty);
      expect(state.unavailableRouteShapes, isEmpty);
      expect(state.allStops.length, equals(3));
    });

    // ── Test 4: Live buses toggle ON/OFF ────────────────────────────────────
    test('4. Live buses toggle fetches and filters vehicles when ON', () async {
      final sampleBuses = [
        const BodsVehicle(
          vehicleRef: 'BUS-1',
          lineRef: '1',
          publishedLineName: '1',
          destinationName: 'City Centre',
          latitude: 51.4816,
          longitude: -3.1791,
        ),
        const BodsVehicle(
          vehicleRef: 'BUS-88',
          lineRef: '88',
          publishedLineName: '88',
          destinationName: 'Other',
          latitude: 51.5000,
          longitude: -3.1800,
        ),
      ];

      final mockBods = MockBodsRepository(mockVehicles: sampleBuses);
      final notifier = RouteMapNotifier(
        gtfsRepository: gtfsRepository,
        bodsRepository: mockBods,
      );

      await notifier.initGtfs(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );

      notifier.toggleRouteSelection('1');
      notifier.toggleLiveBuses(true);

      // Wait for microtask / async fetch
      await Future.delayed(Duration.zero);

      expect(notifier.state.showLiveBuses, isTrue);
      expect(notifier.state.liveBuses.length, equals(1));
      expect(notifier.state.liveBuses.first.vehicleRef, equals('BUS-1'));

      // Toggle OFF -> clears live buses
      notifier.toggleLiveBuses(false);
      expect(notifier.state.showLiveBuses, isFalse);
      expect(notifier.state.liveBuses, isEmpty);
    });

    // ── Test 5: No live buses available ─────────────────────────────────────
    test('5. No live buses available handles empty list or backend errors', () async {
      final failingBods = MockBodsRepository(shouldFail: true);
      final notifier = RouteMapNotifier(
        gtfsRepository: gtfsRepository,
        bodsRepository: failingBods,
      );

      await notifier.initGtfs(
        routesCsv: kTestRoutesCsv,
        tripsCsv: kTestTripsCsv,
        stopsCsv: kTestStopsCsv,
        stopTimesCsv: kTestStopTimesCsv,
        shapesCsv: kTestShapesCsv,
      );

      notifier.toggleRouteSelection('1');
      notifier.toggleLiveBuses(true);

      await Future.delayed(Duration.zero);

      expect(notifier.state.showLiveBuses, isTrue);
      // Handles 503 error gracefully without crashing, returning empty liveBuses list
      expect(notifier.state.liveBuses, isEmpty);
      expect(notifier.state.isLoadingLiveBuses, isFalse);
    });
  });
}
