import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/api_config.dart';
import '../../core/constants.dart';
import '../models/prediction.dart';

class PredictionRepository {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Fetches a delay prediction by calling the backend API or Cloud Function.
  ///
  /// [timeOfDay] should be in "HH:mm" format.
  Future<Prediction> getPrediction({
    required String stopId,
    required String busLine,
    required String timeOfDay,
    String? stopName,
  }) async {
    // 1. Try Node.js Express backend
    try {
      final queryParams = <String, String>{
        'stop': stopId,
        'line': busLine,
        'time': timeOfDay,
      };
      if (stopName != null && stopName.isNotEmpty) {
        queryParams['stop_name'] = stopName;
      }

      final uri = Uri.parse('${ApiConfig.backendBaseUrl}/api/predictions').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (stopName != null && stopName.isNotEmpty) {
          data['stop_name'] = stopName;
        } else {
          data['stop_name'] ??= 'Stop #$stopId';
        }
        data['bus_line'] ??= busLine;
        data['time_of_day'] ??= timeOfDay;
        return Prediction.fromJson(data);
      }
    } catch (e) {
      debugPrint('⚠️ Node.js backend prediction query error: $e');
    }

    // 2. Try Firebase Cloud Functions fallback
    try {
      final HttpsCallable callable = _functions.httpsCallable(
        kPredictionFunctionName,
      );
      final result = await callable.call({
        'stopId': stopId,
        'busLine': busLine,
        'timeOfDay': timeOfDay,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      data['stop_name'] ??= stopName ?? 'Stop #$stopId';
      data['bus_line'] ??= busLine;
      data['time_of_day'] ??= timeOfDay;
      return Prediction.fromJson(data);
    } catch (e) {
      debugPrint('⚠️ Firebase cloud function fallback error: $e');
    }

    // 3. If no data exists or backend is unreachable, return truthful 0 sample size prediction
    return Prediction(
      predictedDelayMinutes: 0.0,
      scheduledDurationMinutes: 0.0,
      averageActualDurationMinutes: 0.0,
      confidenceLevel: 'None',
      sampleSize: 0,
      stopName: stopName ?? 'Stop #$stopId',
      busLine: busLine,
      timeOfDay: timeOfDay,
    );
  }
}
