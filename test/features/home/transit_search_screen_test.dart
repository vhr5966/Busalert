import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busalert/data/models/bus_stop.dart';
import 'package:busalert/data/services/stop_service.dart';
import 'package:busalert/features/home/screens/transit_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BusStop> allStops;

  setUpAll(() async {
    final stopService = StopService();
    allStops = await stopService.getStops();
  });

  group('TransitSearchScreen Widget Tests', () {
    testWidgets('Renders search input, LOCATIONS and TIMETABLES tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TransitSearchScreen(initialStops: allStops),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify search input
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search places, bus stops or routes…'), findsOneWidget);

      // Verify tabs
      expect(find.text('LOCATIONS'), findsOneWidget);
      expect(find.text('TIMETABLES'), findsOneWidget);
    });

    testWidgets('Searching "Royal g" matches Royal Gwent Hospital stops with Newport locality', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TransitSearchScreen(initialStops: allStops),
          ),
        ),
      );

      await tester.pump();

      // Enter query "Royal g" as in professor's reference screenshot
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Royal g');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify matching stops are found
      expect(find.textContaining('Royal Gwent Hospital'), findsWidgets);

      // Verify Newport locality is displayed in subtitle
      expect(find.textContaining('Newport'), findsWidgets);
    });

    testWidgets('TIMETABLES tab displays official routes and filters correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TransitSearchScreen(initialStops: allStops),
          ),
        ),
      );

      await tester.pump();

      // Tap on TIMETABLES tab
      await tester.tap(find.text('TIMETABLES'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Search for Route 30
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '30');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Line 30 is displayed
      expect(find.text('Line 30'), findsOneWidget);
      expect(find.textContaining('Newport'), findsWidgets);
    });

    testWidgets('Tapping a stop opens the action bottom sheet with direct actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: TransitSearchScreen(initialStops: allStops),
          ),
        ),
      );

      await tester.pump();

      // Search for Royal Gwent
      await tester.enterText(find.byType(TextField), 'Royal Gwent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the first stop
      final firstStopTile = find.textContaining('Royal Gwent Hospital').first;
      await tester.tap(firstStopTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify action sheet options are displayed (Plan Journey, Live Departures, View on Map)
      expect(find.text('Plan Journey to this Stop'), findsOneWidget);
      expect(find.text('View Live Departures & Timetable'), findsOneWidget);
      expect(find.text('View Stop on Map'), findsOneWidget);
    });
  });
}
