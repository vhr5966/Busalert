import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/features/profile/screens/profile_history_screen.dart';
import 'package:busalert/features/settings/screens/settings_screen.dart';
import 'package:busalert/screens/home_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'is_guest_mode': true,
    });
  });

  group('Profile & Settings UI Rendering Tests', () {
    testWidgets('ProfileHistoryScreen renders in Guest mode without crashes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfileHistoryScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Guest Passenger'), findsOneWidget);
      expect(find.text('Cardiff Transit Community • Local Storage'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Journeys Logged'), findsOneWidget);
      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('General Settings'), findsOneWidget);
      expect(find.text('Offline Transit Database'), findsOneWidget);
      expect(find.text('About BusAlert Cardiff'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders in Guest mode without crashes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Guest Mode'), findsOneWidget);
      expect(find.text('WiFi bus-line detection'), findsOneWidget);
      expect(find.text('Cardiff GTFS Stops Cache'), findsOneWidget);
      expect(find.text('Data Sources'), findsOneWidget);
    });

    testWidgets('HomeDashboard tab switching to Profile renders cleanly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Profile tab (index 3)
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Guest Passenger'), findsOneWidget);
      expect(find.text('Settings & Preferences'), findsOneWidget);
    });
  });
}
