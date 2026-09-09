import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/services/stop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Royal Gwent Hospital Stops & Routes Verification Tests', () {
    late StopService stopService;

    setUp(() {
      stopService = StopService();
    });

    test('StopService loads comprehensive dataset containing Royal Gwent Hospital stops', () async {
      final stops = await stopService.getStops();

      // Dataset should contain over 3,000 stops covering Cardiff, Vale of Glamorgan, and Newport
      expect(stops.length, greaterThan(3000));

      // Find Royal Gwent Hospital stops
      final gwentStops = stops.where((s) => s.name.toLowerCase().contains('royal gwent')).toList();
      expect(gwentStops.length, greaterThanOrEqualTo(2));

      // Specifically check for both directions: (opp) and (tu allan)
      final oppStop = gwentStops.firstWhere(
        (s) => s.atcoCode == '5310AWB30508' || s.name.contains('(opp)'),
      );
      final tuAllanStop = gwentStops.firstWhere(
        (s) => s.atcoCode == '5310AWB30509' || s.name.contains('(tu allan)'),
      );

      expect(oppStop.name, contains('Royal Gwent Hospital'));
      expect(tuAllanStop.name, contains('Royal Gwent Hospital'));

      // Verify that Royal Gwent Hospital stops are associated with Route 30
      expect(oppStop.routes, contains('30'));
      expect(tuAllanStop.routes, contains('30'));
    });

    test('Fuzzy and token search matches Royal Gwent Hospital stops properly', () async {
      final stops = await stopService.getStops();

      // Case 1: Search "Royal g" as in professor's screenshot
      const query1 = 'Royal g';
      final tokens1 = query1.toLowerCase().split(' ');
      final results1 = stops.where((s) {
        final name = s.name.toLowerCase();
        return tokens1.every((t) => name.contains(t) || s.routes.contains(t));
      }).toList();

      expect(results1.any((s) => s.name.contains('Royal Gwent Hospital')), isTrue);

      // Case 2: Search "Royal gwent"
      const query2 = 'Royal gwent';
      final tokens2 = query2.toLowerCase().split(' ');
      final results2 = stops.where((s) {
        final name = s.name.toLowerCase();
        return tokens2.every((t) => name.contains(t) || s.routes.contains(t));
      }).toList();

      expect(results2.length, greaterThanOrEqualTo(2));
      expect(results2.any((s) => s.name.contains('(opp)')), isTrue);
      expect(results2.any((s) => s.name.contains('(tu allan)')), isTrue);

      // Case 3: Filter by Line 30
      final line30Stops = stops.where((s) => s.routes.contains('30')).toList();
      expect(line30Stops.any((s) => s.name.contains('Royal Gwent Hospital')), isTrue);
    });
  });
}
