import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Strathnairn Street Phantom Departure Bug Fix Tests', () {
    final gtfsRepository = GtfsRepository();
    final timetableRepository = TimetableRepository(gtfsRepository: gtfsRepository);

    const strathnairnStop = BusStop(
      id: 571010614,
      name: 'Strathnairn Street',
      latitude: 51.49186,
      longitude: -3.17106,
      routes: ['24', '27'],
    );

    test('At Strathnairn Street with real schedule (22:37, 22:54, 23:07, 23:24)', () async {
      // Mock GTFS schedule matching Strathnairn Street's real late-night departures
      const mockRoutesCsv = 'route_id,route_short_name,route_long_name\nR27,27,Cardiff - Thornhill';
      const mockTripsCsv = '''route_id,service_id,trip_id,trip_headsign,shape_id
R27,S1,T2237,Thornhill,SH1
R27,S1,T2254,Thornhill,SH1
R27,S1,T2307,Thornhill,SH1
R27,S1,T2324,Thornhill,SH1''';
      const mockStopsCsv = 'stop_id,stop_name,stop_lat,stop_lon\n571010614,Strathnairn Street,51.49186,-3.17106';
      const mockStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence
T2237,22:37:00,22:37:00,571010614,10
T2254,22:54:00,22:54:00,571010614,10
T2307,23:07:00,23:07:00,571010614,10
T2324,23:24:00,23:24:00,571010614,10''';
      const mockShapesCsv = 'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nSH1,51.49186,-3.17106,1';

      await gtfsRepository.loadGtfsData(
        routesCsv: mockRoutesCsv,
        tripsCsv: mockTripsCsv,
        stopsCsv: mockStopsCsv,
        stopTimesCsv: mockStopTimesCsv,
        shapesCsv: mockShapesCsv,
      );

      // Case 1: System time at 23:00 (before last bus) -> returns 23:07 & 23:24
      final departuresAt2300 = await timetableRepository.getRealTimeTimetable(
        stop: strathnairnStop,
        routeNumber: '27',
        relativeTo: DateTime(2026, 8, 20, 23, 0),
      );
      expect(departuresAt2300.length, equals(2));
      expect(departuresAt2300[0].scheduledDeparture, equals('23:07'));
      expect(departuresAt2300[1].scheduledDeparture, equals('23:24'));

      // Case 2: System time at 23:25 (after genuine last bus at 23:24) -> strictly empty list
      final departuresAt2325 = await timetableRepository.getRealTimeTimetable(
        stop: strathnairnStop,
        routeNumber: '27',
        relativeTo: DateTime(2026, 8, 20, 23, 25),
      );
      expect(departuresAt2325, isEmpty);
    });
  });
}
