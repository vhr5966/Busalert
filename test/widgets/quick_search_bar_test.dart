import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/widgets/quick_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuickSearchBar Widget Tests', () {
    testWidgets('Renders search icon button in initial state', (tester) async {
      int? navigatedTab;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  QuickSearchBar(
                    onNavigate: (tabIndex) {
                      navigatedTab = tabIndex;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify search icon button is present with tooltip
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byTooltip('Quick search'), findsOneWidget);
    });

    testWidgets('Tapping search icon opens search view', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  QuickSearchBar(
                    onNavigate: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Search hint should be visible
      expect(find.text('Search stops or routes…'), findsOneWidget);
    });
  });
}
