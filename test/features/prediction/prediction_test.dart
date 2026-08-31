import 'package:flutter_test/flutter_test.dart';
import 'package:busalert/data/models/prediction.dart';

void main() {
  group('Prediction Model Tests', () {
    test('Prediction properties and delay status helpers work as expected', () {
      const predOnTime = Prediction(
        predictedDelayMinutes: 1.5,
        scheduledDurationMinutes: 15,
        averageActualDurationMinutes: 16.5,
        confidenceLevel: 'High',
        sampleSize: 24,
        stopName: 'Kingsway',
        busLine: '27',
        timeOfDay: '08:30',
      );

      expect(predOnTime.isOnTime, isTrue);
      expect(predOnTime.isMinorDelay, isFalse);
      expect(predOnTime.isMajorDelay, isFalse);

      const predMinor = Prediction(
        predictedDelayMinutes: 5.0,
        scheduledDurationMinutes: 20,
        averageActualDurationMinutes: 25.0,
        confidenceLevel: 'Medium',
        sampleSize: 10,
        stopName: 'Greyfriars Road',
        busLine: '35',
        timeOfDay: '09:00',
      );

      expect(predMinor.isOnTime, isFalse);
      expect(predMinor.isMinorDelay, isTrue);
      expect(predMinor.isMajorDelay, isFalse);
    });
  });
}
