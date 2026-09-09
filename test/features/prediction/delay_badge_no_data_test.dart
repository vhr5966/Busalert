import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/widgets/delay_indicator.dart';
import 'package:busalert/data/models/prediction.dart';
import 'package:busalert/features/prediction/screens/prediction_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delay Status Badge & No-Data Alignment Tests', () {
    testWidgets('DelayIndicator renders neutral grey "No Data" when hasData is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayIndicator(
              delayMinutes: 0.0,
              hasData: false,
            ),
          ),
        ),
      );

      // Verify "No Data" is present
      expect(find.text('No Data'), findsOneWidget);
      // Verify "On time" is NOT rendered
      expect(find.text('On time'), findsNothing);
      // Verify help/info icon is rendered, not check_circle
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('DelayIndicator renders green "On time" only when hasData is true and delay <= 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayIndicator(
              delayMinutes: 1.0,
              hasData: true,
            ),
          ),
        ),
      );

      expect(find.text('On time'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('PredictionResultScreen shows warning message and NO green On-time badge when sampleSize is 0', (tester) async {
      const emptyPrediction = Prediction(
        predictedDelayMinutes: 0.0,
        scheduledDurationMinutes: 0.0,
        averageActualDurationMinutes: 0.0,
        confidenceLevel: 'Low',
        sampleSize: 0, // No real-time / historical data available
        stopName: 'Strathnairn Street',
        busLine: '27',
        timeOfDay: '14:30',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: PredictionResultScreen(
            prediction: emptyPrediction,
          ),
        ),
      );

      // Verify truthful data warning message is shown
      expect(find.text('Not enough real-time data is available for a reliable prediction.'), findsOneWidget);
      
      // Verify no green "On time" badge is rendered
      expect(find.text('On time'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
