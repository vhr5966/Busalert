import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/repositories/gtfs_repository.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bidirectional Timetable Tests', () {
    late GtfsRepository gtfsRepo;

    setUp(() async {
      gtfsRepo = GtfsRepository();
      if (!gtfsRepo.isLoaded) {
        await gtfsRepo.loadGtfsData();
      }
    });

    test('Route 9 resolves both Direction 0 and Direction 1 termini', () {
      final directions = gtfsRepo.getRouteDirections('9');

      expect(directions.routeNumber, equals('9'));
      expect(directions.direction0, isNotNull);
      expect(directions.direction1, isNotNull);

      // Direction 0: Point A -> Point B (Sports Village / Cardiff Bay -> Heath Hospital)
      final dir0 = directions.direction0!;
      expect(dir0.routeNumber, equals('9'));
      expect(dir0.directionId, equals(0));
      expect(
        dir0.originStop.name.toLowerCase(),
        anyOf(contains('sports village'), contains('cardiff bay')),
      );
      expect(dir0.destinationStop.name.toLowerCase(), contains('heath hospital'));
      expect(dir0.stops, isNotEmpty);
      expect(dir0.destinationName, contains('Heath Hospital'));

      // Direction 1: Point B -> Point A (Heath Hospital -> Sports Village / Cardiff Bay / Dunleavy Drive)
      final dir1 = directions.direction1!;
      expect(dir1.routeNumber, equals('9'));
      expect(dir1.directionId, equals(1));
      expect(dir1.originStop.name.toLowerCase(), contains('heath hospital'));
      expect(
        dir1.destinationStop.name.toLowerCase(),
        anyOf(
          contains('sports village'),
          contains('cardiff bay'),
          contains('dunleavy'),
        ),
      );
      expect(dir1.stops, isNotEmpty);
      expect(
        dir1.destinationName.toLowerCase(),
        anyOf(contains('sports village'), contains('cardiff bay')),
      );
    });

    test('Route 11 resolves bidirectional directions', () {
      final directions = gtfsRepo.getRouteDirections('11');

      expect(directions.direction0, isNotNull);
      expect(directions.direction1, isNotNull);

      final dir0 = directions.direction0!;
      final dir1 = directions.direction1!;

      expect(dir0.routeNumber, equals('11'));
      expect(dir1.routeNumber, equals('11'));
      expect(dir0.directionId, equals(0));
      expect(dir1.directionId, equals(1));
      expect(dir0.stops, isNotEmpty);
      expect(dir1.stops, isNotEmpty);
    });

    test('Route 1 resolves paired opposite route 2 for circular service', () {
      final directions = gtfsRepo.getRouteDirections('1');

      expect(directions.direction0, isNotNull);
      expect(directions.direction1, isNotNull);

      final dir0 = directions.direction0!;
      final dir1 = directions.direction1!;

      // Direction 0 is Line 1 (Clockwise), Direction 1 is Line 2 (Anti-Clockwise)
      expect(dir0.routeNumber, equals('1'));
      expect(dir1.routeNumber, equals('2'));
      expect(dir0.stops, isNotEmpty);
      expect(dir1.stops, isNotEmpty);
      expect(dir0.destinationName, contains('Clockwise'));
      expect(dir1.destinationName, contains('Anti-Clockwise'));
    });

    test('Circular routes (17/18, 21/23, 24/25) resolve paired directions', () {
      final directions17 = gtfsRepo.getRouteDirections('17');
      expect(directions17.direction0?.routeNumber, equals('17'));
      expect(directions17.direction1?.routeNumber, equals('18'));

      final directions21 = gtfsRepo.getRouteDirections('21');
      expect(directions21.direction0?.routeNumber, equals('21'));
      expect(directions21.direction1?.routeNumber, equals('23'));

      final directions24 = gtfsRepo.getRouteDirections('24');
      expect(directions24.direction0?.routeNumber, equals('24'));
      expect(directions24.direction1?.routeNumber, equals('25'));
    });

    test('Timetable departures can be filtered by directionId for Route 9', () async {
      final directions = gtfsRepo.getRouteDirections('9');
      final dir0Origin = directions.direction0!.originStop;

      final timetableRepo = TimetableRepository();
      final departuresDir0 = await timetableRepo.getRealTimeTimetable(
        stop: dir0Origin,
        routeNumber: '9',
        directionId: 0,
        relativeTo: DateTime(2026, 8, 12, 10, 0),
      );

      for (final dep in departuresDir0) {
        expect(dep.routeNumber, equals('9'));
      }
    });

    test('Different stops along a route produce distinct departure times', () async {
      final timetableRepo = TimetableRepository();
      final canalStreet = const BusStop(
        id: 100,
        name: 'Canal Street',
        latitude: 51.4775,
        longitude: -3.1753,
        routes: ['1'],
      );
      final millenniumCentre = const BusStop(
        id: 200,
        name: 'Millennium Centre',
        latitude: 51.4651,
        longitude: -3.1641,
        routes: ['2'],
      );

      final now = DateTime(2026, 9, 9, 22, 12);
      final depsCanal = await timetableRepo.getRealTimeTimetable(
        stop: canalStreet,
        routeNumber: '1',
        relativeTo: now,
      );
      final depsMillennium = await timetableRepo.getRealTimeTimetable(
        stop: millenniumCentre,
        routeNumber: '2',
        relativeTo: now,
      );

      expect(depsCanal, isNotEmpty);
      expect(depsMillennium, isNotEmpty);

      // Departure minutes for Canal Street and Millennium Centre should not be identical
      expect(
        depsCanal.first.scheduledDeparture,
        isNot(equals(depsMillennium.first.scheduledDeparture)),
      );
    });
  });
}
