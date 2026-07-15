/// Repository for delay prediction operations using Firebase Functions.
///
/// Calls the `getPrediction` Cloud Function which computes a weighted
/// moving average of historical journey records in Firestore.
///
/// Falls back to mock data if the Cloud Function is unavailable
/// (e.g. during development without Firebase emulators running).
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../core/constants.dart';
import '../models/prediction.dart';

class PredictionRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetches a delay prediction by calling the Firebase Cloud Function.
  ///
  /// [timeOfDay] should be in "HH:mm" format.
  Future<Prediction> getPrediction({
    required String stopId,
    required String busLine,
    required String timeOfDay,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        kPredictionFunctionName,
      );
      final result = await callable.call({
        'stopId': stopId,
        'busLine': busLine,
        'timeOfDay': timeOfDay,
      });

      return Prediction.fromJson(result.data as Map<String, dynamic>);
    } catch (e) {
      // If the Cloud Function fails (e.g. not deployed yet), fall back
      // to mock data so the UI can still be demonstrated.
      return getMockPrediction(
        stopId: stopId,
        busLine: busLine,
        timeOfDay: timeOfDay,
      );
    }
  }

  /// Returns a mock prediction for testing when the Cloud Function
  /// is unavailable (e.g. during development).
  Future<Prediction> getMockPrediction({
    required String stopId,
    required String busLine,
    required String timeOfDay,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final delay = switch (busLine) {
      '1' || '2' => 5.0,
      '8' || '9' => 12.0,
      '28' || '29' => 3.0,
      _ => 7.5,
    };

    return Prediction(
      predictedDelayMinutes: delay,
      scheduledDurationMinutes: 25.0,
      averageActualDurationMinutes: 25.0 + delay,
      confidenceLevel: delay > 10 ? 'Low' : 'Medium',
      sampleSize: delay > 10 ? 4 : 28,
      stopName: 'Stop #$stopId',
      busLine: busLine,
      timeOfDay: timeOfDay,
    );
  }
}
