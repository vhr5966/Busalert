import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/models/gtfs_model.dart';
import 'package:busalert/data/repositories/timetable_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time Timetable Tests', () {
    test('TimetableEntry status helpers and minute calculation', () {
      final now = DateTime(2026, 8, 12, 14, 20);

      final entryOnTime = TimetableEntry(
        tripId: 'trip-1',
        routeNumber: '27',
        headsign: 'Thornhill',
        stopId: 'stop-1',
        stopName: 'Cardiff Central',
        scheduledDeparture: '14:25',
        predictedDeparture: '14:25',
        delayMinutes: 0.0,
        isLive: true,
      );

      expect(entryOnTime.statusLabel, 'On Time');
      expect(entryOnTime.minutesUntilText(now), 'in 5 mins');
      expect(entryOnTime.statusColor.value, isNotNull);

      final entryDelayed = TimetableEntry(
        tripId: 'trip-2',
        routeNumber: '6',
        headsign: 'Cardiff Bay',
        stopId: 'stop-1',
        stopName: 'Cardiff Central',
        scheduledDeparture: '14:25',
        predictedDeparture: '14:30',
        delayMinutes: 5.0,
        isLive: true,
      );

      expect(entryDelayed.statusLabel, '+5 min delay');
      expect(entryDelayed.minutesUntilText(now), 'in 10 mins');
    });

    test('TimetableRepository returns departures for bus stop', () async {
      final repo = TimetableRepository();
      const stop = BusStop(
        id: 1,
        name: 'Cardiff Central Station',
        latitude: 51.4757,
        longitude: -3.1791,
        routes: ['27', '6'],
      );

      final departures = await repo.getRealTimeTimetable(
        stop: stop,
        routeNumber: '27',
        relativeTo: DateTime(2026, 8, 12, 12, 0),
      );

      expect(departures, isNotEmpty);
      expect(departures.first.stopName, equals('Cardiff Central Station'));
      expect(departures.first.routeNumber, equals('27'));
    });
  });
}
