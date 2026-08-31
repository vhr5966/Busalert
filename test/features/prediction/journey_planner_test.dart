import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/planned_journey.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlannedJourney Model Tests', () {
    test('Calculates countdown and status labels properly', () {
      final now = DateTime(2026, 8, 22, 14, 0);

      const journey = PlannedJourney(
        routeNumber: '27',
        headsign: 'Cardiff Central',
        originStopId: 'STOP_A',
        originStopName: 'Strathnairn Street',
        destinationStopId: 'STOP_B',
        destinationStopName: 'Cardiff Central Station',
        departureTime: '14:15',
        arrivalTime: '14:32',
        durationMinutes: 17,
        stopsCount: 8,
        delayMinutes: 1.5,
        isLive: true,
      );

      expect(journey.departureCountdown(now), equals('in 15 mins'));
      expect(journey.statusLabel, contains('On Time'));
      expect(journey.durationMinutes, equals(17));
      expect(journey.stopsCount, equals(8));
    });

    test('Status color maps correctly for delays', () {
      const onTime = PlannedJourney(
        routeNumber: '1',
        headsign: 'City',
        originStopId: 'A',
        originStopName: 'A',
        destinationStopId: 'B',
        destinationStopName: 'B',
        departureTime: '10:00',
        arrivalTime: '10:10',
        durationMinutes: 10,
        stopsCount: 5,
        delayMinutes: 0.0,
      );
      expect(onTime.statusLabel, equals('On Time'));

      const majorDelay = PlannedJourney(
        routeNumber: '1',
        headsign: 'City',
        originStopId: 'A',
        originStopName: 'A',
        destinationStopId: 'B',
        destinationStopName: 'B',
        departureTime: '10:00',
        arrivalTime: '10:10',
        durationMinutes: 10,
        stopsCount: 5,
        delayMinutes: 15.0,
      );
      expect(majorDelay.statusLabel, equals('+15 min delay'));
    });
  });

  group('GtfsRepository.findDirectJourneys Algorithm Tests', () {
    late GtfsRepository repository;

    const testRoutesCsv = '''route_id,route_short_name,route_long_name,route_type
R27,27,Thornhill - Cardiff,3
R28,28,Llanishen - Cardiff,3
''';

    const testTripsCsv = '''route_id,service_id,trip_id,trip_headsign,direction_id,block_id,shape_id
R27,S1,T27_1,Cardiff Central,0,,SH1
R28,S1,T28_1,Cardiff Central,0,,SH2
''';

    const testStopsCsv = '''stop_id,stop_code,stop_name,stop_lat,stop_lon
STOP_ORIGIN,,Strathnairn Street,51.4850,-3.1650
STOP_MID,,Albany Road,51.4860,-3.1680
STOP_DEST,,Cardiff Central,51.4750,-3.1790
STOP_OTHER,,Unrelated Stop,51.5000,-3.1000
''';

    const testStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence,pickup_type,drop_off_type
T27_1,14:10:00,14:10:00,STOP_ORIGIN,1,0,0
T27_1,14:15:00,14:15:00,STOP_MID,2,0,0
T27_1,14:28:00,14:28:00,STOP_DEST,3,0,0
T28_1,14:20:00,14:20:00,STOP_ORIGIN,1,0,0
T28_1,14:38:00,14:38:00,STOP_DEST,2,0,0
''';

    setUp(() async {
      repository = GtfsRepository();
      await repository.loadGtfsData(
        routesCsv: testRoutesCsv,
        tripsCsv: testTripsCsv,
        stopsCsv: testStopsCsv,
        stopTimesCsv: testStopTimesCsv,
        shapesCsv: '',
      );
    });

    test('Finds direct journey when origin sequence < destination sequence', () {
      final now = DateTime(2026, 8, 22, 14, 0);

      final journeys = repository.findDirectJourneys(
        originStopId: 'STOP_ORIGIN',
        destinationStopId: 'STOP_DEST',
        relativeTo: now,
      );

      expect(journeys.length, equals(2));
      final j = journeys.first;
      expect(j.routeNumber, equals('27'));
      expect(j.departureTime, equals('14:10'));
      expect(j.arrivalTime, equals('14:28'));
      expect(j.durationMinutes, equals(18));
      expect(j.stopsCount, equals(2));
    });

    test('Filters journeys by preferredRouteNumber', () {
      final now = DateTime(2026, 8, 22, 14, 0);

      final r28Only = repository.findDirectJourneys(
        originStopId: 'STOP_ORIGIN',
        destinationStopId: 'STOP_DEST',
        preferredRouteNumber: '28',
        relativeTo: now,
      );

      expect(r28Only.length, equals(1));
      expect(r28Only.first.routeNumber, equals('28'));
      expect(r28Only.first.departureTime, equals('14:20'));

      final r27Only = repository.findDirectJourneys(
        originStopId: 'STOP_ORIGIN',
        destinationStopId: 'STOP_DEST',
        preferredRouteNumber: '27',
        relativeTo: now,
      );

      expect(r27Only.length, equals(1));
      expect(r27Only.first.routeNumber, equals('27'));
      expect(r27Only.first.departureTime, equals('14:10'));
    });

    test('Returns empty when destination is before origin or unrelated', () {
      final now = DateTime(2026, 8, 22, 14, 0);

      // Reverse direction should return empty (STOP_DEST is at seq 3, STOP_ORIGIN is at seq 1)
      final reverse = repository.findDirectJourneys(
        originStopId: 'STOP_DEST',
        destinationStopId: 'STOP_ORIGIN',
        relativeTo: now,
      );
      expect(reverse, isEmpty);

      // Unrelated stop should return empty
      final unrelated = repository.findDirectJourneys(
        originStopId: 'STOP_ORIGIN',
        destinationStopId: 'STOP_OTHER',
        relativeTo: now,
      );
      expect(unrelated, isEmpty);
    });
  });

  group('DestinationPlannerCard Smoke Tests', () {
    test('PlannedJourney departureCountdown returns correct strings', () {
      const journey = PlannedJourney(
        routeNumber: '27',
        headsign: 'Cardiff Central',
        originStopId: 'STOP_A',
        originStopName: 'Strathnairn Street',
        destinationStopId: 'STOP_B',
        destinationStopName: 'Cardiff Central Station',
        departureTime: '10:05',
        arrivalTime: '10:22',
        durationMinutes: 17,
        stopsCount: 8,
        delayMinutes: 0.0,
      );

      final now = DateTime(2026, 8, 22, 10, 0);
      expect(journey.departureCountdown(now), equals('in 5 mins'));

      final past = DateTime(2026, 8, 22, 10, 10);
      expect(journey.departureCountdown(past), equals('Due now'));
    });
  });
}
