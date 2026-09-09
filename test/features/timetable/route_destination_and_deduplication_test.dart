import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/services/route_destination_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteDestinationResolver Tests', () {
    test('Route 17 at City Centre stop resolves to Ely & Caerau via Canton', () {
      final dest = RouteDestinationResolver.resolveDestination(
        routeNumber: '17',
        stopName: 'Westgate Street KL (o/s)',
        rawHeadsign: 'City Centre',
      );
      expect(dest, equals('Ely & Caerau via Canton'));
    });

    test('Route 17 along the loop resolves to City Centre via Canton for return leg', () {
      final dest = RouteDestinationResolver.resolveDestination(
        routeNumber: '17',
        stopName: 'Ely Grand Avenue (nr)',
        rawHeadsign: 'City Centre',
      );
      expect(dest, equals('City Centre via Canton'));
    });

    test('Route 18 at Wood Street resolves to Canton & Ely via Grand Ave', () {
      final dest = RouteDestinationResolver.resolveDestination(
        routeNumber: '18',
        stopName: 'Wood Street JA',
        rawHeadsign: 'City Centre',
      );
      expect(dest, equals('Canton & Ely via Grand Ave'));
    });

    test('Route 44 and 45 have distinct via corridors and do not repeat generic St. Mellons', () {
      final dest44 = RouteDestinationResolver.resolveDestination(
        routeNumber: '44',
        stopName: 'Stacey Road (opp)',
        rawHeadsign: 'St. Mellons',
      );
      final dest45 = RouteDestinationResolver.resolveDestination(
        routeNumber: '45',
        stopName: 'Stacey Road (opp)',
        rawHeadsign: 'St. Mellons',
      );

      expect(dest44, equals('St. Mellons via Rumney & New Rd'));
      expect(dest45, equals('St. Mellons via Llanrumney'));
      expect(dest44, isNot(equals(dest45)));
    });

    test('Route 30 resolves to Newport Bus Station via Castleton', () {
      final dest30 = RouteDestinationResolver.resolveDestination(
        routeNumber: '30',
        stopName: 'Stacey Road (opp)',
        rawHeadsign: 'Newport Bus Station',
      );
      expect(dest30, equals('Newport Bus Station via Castleton'));
    });

    test('Route 1 and Route 2 circular clockwise/anti-clockwise resolution', () {
      final dest1 = RouteDestinationResolver.resolveDestination(
        routeNumber: '1',
        stopName: 'Cardiff Bay Station',
      );
      final dest2 = RouteDestinationResolver.resolveDestination(
        routeNumber: '2',
        stopName: 'Albany Road',
      );
      expect(dest1, equals('City Circle (Clockwise)'));
      expect(dest2, equals('City Circle (Anti-Clockwise)'));
    });
  });

  group('GtfsRepository Deduplication Tests', () {
    test('getUpcomingDeparturesForStop strictly deduplicates identical route and minute departures', () async {
      final gtfsRepo = GtfsRepository();

      const testRoutesCsv = '''route_id,route_short_name,route_long_name,route_type
CB:44,44,Cardiff - St Mellons,3
''';

      // Two trips on Sunday with the exact same departure time 22:17 at STOP_1
      const testTripsCsv = '''route_id,service_id,trip_id,trip_headsign,direction_id,block_id,shape_id
CB:44,CB:44:SUSH:1,TRIP_44_1,"St. Mellons",0,,SH1
CB:44,CB:44:SUSH:2,TRIP_44_2,"St. Mellons",0,,SH1
''';

      const testStopsCsv = '''stop_id,stop_code,stop_name,stop_lat,stop_lon
STOP_1,,Stacey Road (opp),51.4914,-3.1536
''';

      const testStopTimesCsv = '''trip_id,arrival_time,departure_time,stop_id,stop_sequence,pickup_type,drop_off_type
TRIP_44_1,22:17:00,22:17:00,STOP_1,1,0,0
TRIP_44_2,22:17:00,22:17:00,STOP_1,1,0,0
''';

      await gtfsRepo.loadGtfsData(
        routesCsv: testRoutesCsv,
        tripsCsv: testTripsCsv,
        stopsCsv: testStopsCsv,
        stopTimesCsv: testStopTimesCsv,
        shapesCsv: '',
      );

      // Sunday 22:00
      final departures = gtfsRepo.getUpcomingDeparturesForStop(
        stopId: 'STOP_1',
        routeNumber: '44',
        relativeTo: DateTime(2026, 8, 23, 22, 0), // Sunday
      );

      // Must be exactly 1 departure at 22:17, never 2 duplicate entries
      expect(departures.length, equals(1));
      expect(departures.first.scheduledDeparture, equals('22:17'));
      expect(departures.first.headsign, equals('St. Mellons via Rumney & New Rd'));
    });
  });
}
