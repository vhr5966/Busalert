import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bods_vehicle.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/models/gtfs_rt_model.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/repositories/bods_repository.dart';
import 'package:busalert/data/services/gtfs_rt_service.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

// Mock GtfsRtService for testing
class MockGtfsRtService extends GtfsRtService {
  List<GtfsRtTripUpdate> mockUpdates = [];

  @override
  Future<List<GtfsRtTripUpdate>> fetchTripUpdates({String? routeNumber}) async {
    if (routeNumber != null && routeNumber.isNotEmpty) {
      return mockUpdates
          .where((u) => u.routeId.toLowerCase() == routeNumber.toLowerCase())
          .toList();
    }
    return mockUpdates;
  }
}

// Mock BodsRepository for testing
class MockBodsRepository extends BodsRepository {
  List<BodsVehicle> mockVehicles = [];

  @override
  Future<List<BodsVehicle>> getAllVehicles() async => mockVehicles;

  @override
  Future<List<BodsVehicle>> getVehiclesForLine(String lineRef) async {
    return mockVehicles
        .where((v) => v.matchesRoute(lineRef))
        .toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GTFS-RT Model Tests', () {
    test('Parses GtfsRtTripUpdate and computes stop-level estimated departures', () {
      final json = {
        'tripId': 'TRIP_27_101',
        'routeId': '27',
        'delaySeconds': 180,
        'timestamp': '2026-08-22T14:00:00.000Z',
        'stopTimeUpdates': [
          {
            'stopId': 'STOP_A',
            'stopSequence': 1,
            'arrivalDelaySeconds': 120,
            'departureDelaySeconds': 120,
          },
          {
            'stopId': 'STOP_B',
            'stopSequence': 2,
            'arrivalDelaySeconds': 300,
            'departureDelaySeconds': 300,
          }
        ]
      };

      final update = GtfsRtTripUpdate.fromJson(json);
      expect(update.tripId, equals('TRIP_27_101'));
      expect(update.routeId, equals('27'));
      expect(update.delayMinutes, equals(3.0));

      final stopA = update.findUpdateForStop(stopId: 'STOP_A');
      expect(stopA, isNotNull);
      expect(stopA!.effectiveDelaySeconds, equals(120));
      expect(stopA.effectiveDelayMinutes, equals(2.0));

      final now = DateTime(2026, 8, 22, 14, 0);
      final estA = update.computeEstimatedDeparture(
        stopId: 'STOP_A',
        scheduledTimeHHmm: '14:10',
        relativeTo: now,
      );
      // 14:10 + 2 mins delay = 14:12
      expect(estA, equals('14:12'));

      final estB = update.computeEstimatedDeparture(
        stopId: 'STOP_B',
        scheduledTimeHHmm: '14:20',
        relativeTo: now,
      );
      // 14:20 + 5 mins delay = 14:25
      expect(estB, equals('14:25'));
    });
  });

  group('Absolute Real-Time Precedence Calculation Formula Tests', () {
    late GtfsRepository gtfsRepo;
    late MockGtfsRtService mockGtfsRt;
    late MockBodsRepository mockBods;
    late TimetableRepository timetableRepo;

    const testRoutesCsv = '''route_id,route_short_name,route_long_name,route_type
R27,27,Thornhill - Cardiff,3
''';

    const testTripsCsv = '''route_id,service_id,trip_id,trip_headsign,direction_id,block_id,shape_id
R27,S1,TRIP_27_A,Cardiff Central,0,,SH1
R27,S1,TRIP_27_B,Cardiff Central,0,,SH1
R27,S1,TRIP_27_C,Cardiff Central,0,,SH1
''';

    const testStopsCsv = '''stop_id,stop_code,stop_name,stop_lat,stop_lon
STOP_1,,Kingsway Stop,51.4815,-3.1800
''';

    const testStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence,pickup_type,drop_off_type
TRIP_27_A,14:10:00,14:10:00,STOP_1,1,0,0
TRIP_27_B,14:25:00,14:25:00,STOP_1,1,0,0
TRIP_27_C,14:40:00,14:40:00,STOP_1,1,0,0
''';

    const testStop = BusStop(
      id: 1,
      atcoCode: 'STOP_1',
      name: 'Kingsway Stop',
      latitude: 51.4815,
      longitude: -3.1800,
      routes: ['27'],
    );

    setUp(() async {
      gtfsRepo = GtfsRepository();
      await gtfsRepo.loadGtfsData(
        routesCsv: testRoutesCsv,
        tripsCsv: testTripsCsv,
        stopsCsv: testStopsCsv,
        stopTimesCsv: testStopTimesCsv,
        shapesCsv: '',
      );

      mockGtfsRt = MockGtfsRtService();
      mockBods = MockBodsRepository();

      timetableRepo = TimetableRepository(
        gtfsRepository: gtfsRepo,
        bodsRepository: mockBods,
        gtfsRtService: mockGtfsRt,
      );
    });

    test('Case 1 (Precedence 1): GTFS-RT Estimated Time overrides static schedule with isLive: true', () async {
      final now = DateTime(2026, 8, 22, 14, 0);

      // GTFS-RT update for TRIP_27_A with 4 min delay (240s)
      mockGtfsRt.mockUpdates = [
        const GtfsRtTripUpdate(
          tripId: 'TRIP_27_A',
          routeId: '27',
          delaySeconds: 240,
          stopTimeUpdates: [
            GtfsRtStopTimeUpdate(
              stopId: 'STOP_1',
              arrivalDelaySeconds: 240,
              departureDelaySeconds: 240,
            ),
          ],
        ),
      ];

      // SIRI-VM also has a vehicle for route 27 with 10 min delay, but GTFS-RT must take precedence for TRIP_27_A
      mockBods.mockVehicles = [
        const BodsVehicle(
          vehicleRef: 'VEH_999',
          lineRef: '27',
          latitude: 51.4815,
          longitude: -3.1800,
          delayMinutes: 10.0,
        ),
      ];

      final results = await timetableRepo.getRealTimeTimetable(
        stop: testStop,
        relativeTo: now,
      );

      expect(results.length, equals(3));

      // TRIP_27_A: uses GTFS-RT (14:10 + 4min = 14:14, isLive: true)
      final tripA = results.firstWhere((e) => e.tripId == 'TRIP_27_A');
      expect(tripA.isLive, isTrue);
      expect(tripA.scheduledDeparture, equals('14:10'));
      expect(tripA.predictedDeparture, equals('14:14'));
      expect(tripA.delayMinutes, equals(4.0));

      // TRIP_27_B: no GTFS-RT, falls back to SIRI-VM Level 2 (14:25 + 10min = 14:35, isLive: true)
      final tripB = results.firstWhere((e) => e.tripId == 'TRIP_27_B');
      expect(tripB.isLive, isTrue);
      expect(tripB.scheduledDeparture, equals('14:25'));
      expect(tripB.predictedDeparture, equals('14:35'));
      expect(tripB.delayMinutes, equals(10.0));
    });

    test('Case 2 (Precedence 2): SIRI-VM Delay overrides static schedule when GTFS-RT is absent', () async {
      final now = DateTime(2026, 8, 22, 14, 0);

      // No GTFS-RT updates
      mockGtfsRt.mockUpdates = [];

      // SIRI-VM vehicle with 3 min delay
      mockBods.mockVehicles = [
        const BodsVehicle(
          vehicleRef: 'VEH_101',
          lineRef: '27',
          latitude: 51.4815,
          longitude: -3.1800,
          delayMinutes: 3.0,
        ),
      ];

      final results = await timetableRepo.getRealTimeTimetable(
        stop: testStop,
        relativeTo: now,
      );

      final tripA = results.firstWhere((e) => e.tripId == 'TRIP_27_A');
      expect(tripA.isLive, isTrue);
      expect(tripA.scheduledDeparture, equals('14:10'));
      expect(tripA.predictedDeparture, equals('14:13'));
      expect(tripA.delayMinutes, equals(3.0));
    });

    test('Case 3 (Precedence 3): Lost GPS tracking returns static scheduled only with isLive: false', () async {
      final now = DateTime(2026, 8, 22, 14, 0);

      // Both GTFS-RT and SIRI-VM feeds empty / tracking lost
      mockGtfsRt.mockUpdates = [];
      mockBods.mockVehicles = [];

      final results = await timetableRepo.getRealTimeTimetable(
        stop: testStop,
        relativeTo: now,
      );

      expect(results.length, equals(3));
      for (final entry in results) {
        expect(entry.isLive, isFalse);
        expect(entry.predictedDeparture, isNull);
        expect(entry.delayMinutes, isNull);
        expect(entry.statusLabel, equals('Scheduled'));
      }
    });
  });
}
