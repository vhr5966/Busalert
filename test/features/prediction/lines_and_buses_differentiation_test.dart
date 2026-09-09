import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busalert/data/models/bods_vehicle.dart';
import 'package:busalert/features/prediction/screens/prediction_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lines vs Live Buses Differentiation Tests', () {
    test('BodsVehicle matchesRoute correctly matches route numbers with operator prefixes', () {
      const vehicle1 = BodsVehicle(
        vehicleRef: '374',
        lineRef: 'CBUS:27',
        publishedLineName: '27',
        destinationName: 'Thornhill',
        latitude: 51.4816,
        longitude: -3.1791,
      );

      expect(vehicle1.matchesRoute('27'), isTrue);
      expect(vehicle1.matchesRoute('CBUS:27'), isTrue);
      expect(vehicle1.matchesRoute('28'), isFalse);

      const vehicle2 = BodsVehicle(
        vehicleRef: '502',
        lineRef: '1',
        destinationName: 'Cardiff Bay',
        latitude: 51.465,
        longitude: -3.165,
      );

      expect(vehicle2.matchesRoute('1'), isTrue);
      expect(vehicle2.matchesRoute('01'), isTrue);
      expect(vehicle2.matchesRoute('1A'), isFalse);
    });

    testWidgets('PredictionScreen renders mixed list with visual legend and distinct icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PredictionScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Visual Legend differentiating Line vs Bus
      expect(find.text('Line (Route)'), findsWidgets);
      expect(find.text('Bus (Vehicle)'), findsWidgets);
      expect(find.byIcon(Icons.alt_route_rounded), findsWidgets);
      expect(find.byIcon(Icons.directions_bus_rounded), findsWidgets);

      // Verify Line badges have 'LINE' label and line icon in mixed list
      expect(find.text('LINE'), findsWidgets);
      expect(find.text('Cardiff Bus Line Timetables'), findsOneWidget);
    });
  });
}
