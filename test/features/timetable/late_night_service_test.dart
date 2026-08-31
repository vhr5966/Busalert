import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/models/bods_vehicle.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Late-Night Operating Hours & 24+ Hour Time Parsing Tests', () {
    final gtfsRepository = GtfsRepository();
    final timetableRepository = TimetableRepository(gtfsRepository: gtfsRepository);

    const sampleStop = BusStop(
      id: 57101,
      name: 'Cardiff Central Station',
      latitude: 51.478,
      longitude: -3.178,
      routes: ['1', '27', 'N1'],
    );

    test('GTFS 24+ hour format (e.g. 24:15) normalizes to 00:15', () async {
      const mockRoutesCsv = 'route_id,route_short_name,route_long_name\nR27,27,Cardiff - Thornhill';
      const mockTripsCsv = 'route_id,service_id,trip_id,trip_headsign,shape_id\nR27,S1,T24,Thornhill,SH1';
      const mockStopsCsv = 'stop_id,stop_name,stop_lat,stop_lon\n57101,Cardiff Central,51.478,-3.178';
      const mockStopTimesCsv = 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT24,24:15:00,24:15:00,57101,1';
      const mockShapesCsv = 'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\nSH1,51.478,-3.178,1';

      await gtfsRepository.loadGtfsData(
        routesCsv: mockRoutesCsv,
        tripsCsv: mockTripsCsv,
        stopsCsv: mockStopsCsv,
        stopTimesCsv: mockStopTimesCsv,
        shapesCsv: mockShapesCsv,
      );

      final lateNightTime = DateTime(2026, 8, 20, 23, 55); // 11:55 PM
      final departures = gtfsRepository.getUpcomingDeparturesForStop(
        stopId: 'S57101',
        relativeTo: lateNightTime,
      );

      expect(departures.isNotEmpty, isTrue);
      // Departure at 24:15 should format as 00:15
      expect(departures.first.scheduledDeparture, equals('00:15'));
    });

    test('Late night (past 11:00 PM) returns empty for day routes when no live bus active', () async {
      await gtfsRepository.loadGtfsData(
        routesCsv: 'route_id,route_short_name,route_long_name\nR27,27,Cardiff - Thornhill',
        tripsCsv: 'route_id,service_id,trip_id,trip_headsign,shape_id',
        stopsCsv: 'stop_id,stop_name,stop_lat,stop_lon\n57101,Cardiff Central,51.478,-3.178',
        stopTimesCsv: 'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
        shapesCsv: 'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence',
      );

      final past11Pm = DateTime(2026, 8, 20, 23, 15); // 11:15 PM

      final departures = await timetableRepository.getRealTimeTimetable(
        stop: sampleStop,
        routeNumber: '99',
        relativeTo: past11Pm,
      );

      // Past 11 PM with no GTFS trip & no live bus should return empty (Service Ended)
      // rather than generating fake 15-minute offset fallback entries
      expect(departures.isEmpty, isTrue);
    });

    test('Night routes (N-prefix) retain service past 11:00 PM', () async {
      final past11Pm = DateTime(2026, 8, 20, 23, 30);

      final departures = await timetableRepository.getRealTimeTimetable(
        stop: sampleStop,
        routeNumber: 'N1',
        relativeTo: past11Pm,
      );

      // Night route N1 should generate valid service entries past 11:00 PM
      expect(departures.isNotEmpty, isTrue);
      expect(departures.first.routeNumber, equals('N1'));
    });
  });
}
