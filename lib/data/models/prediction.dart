/// Model representing a delay prediction result returned by the backend.
///
/// The backend computes a weighted moving average of historical journey
/// times for a given stop / line / time-of-day and returns a predicted
/// delay along with a confidence level based on sample size.
library;

class Prediction {
  /// The predicted delay in minutes (negative = early, positive = late).
  final double predictedDelayMinutes;

  /// The scheduled (expected) journey duration in minutes.
  final double scheduledDurationMinutes;

  /// The average actual journey duration from historical data.
  final double averageActualDurationMinutes;

  /// A human-readable confidence level: "High", "Medium", or "Low".
  final String confidenceLevel;

  /// The number of historical records used to compute this prediction.
  final int sampleSize;

  /// The bus stop name the prediction is for.
  final String stopName;

  /// The bus line number.
  final String busLine;

  /// The time of day queried.
  final String timeOfDay;

  const Prediction({
    required this.predictedDelayMinutes,
    required this.scheduledDurationMinutes,
    required this.averageActualDurationMinutes,
    required this.confidenceLevel,
    required this.sampleSize,
    required this.stopName,
    required this.busLine,
    required this.timeOfDay,
  });

  /// Creates a [Prediction] from a JSON map returned by the backend.
  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      predictedDelayMinutes: (json['predicted_delay_minutes'] as num).toDouble(),
      scheduledDurationMinutes:
          (json['scheduled_duration_minutes'] as num).toDouble(),
      averageActualDurationMinutes:
          (json['average_actual_duration_minutes'] as num).toDouble(),
      confidenceLevel: json['confidence_level'] as String,
      sampleSize: json['sample_size'] as int,
      stopName: json['stop_name'] as String,
      busLine: json['bus_line'] as String,
      timeOfDay: json['time_of_day'] as String,
    );
  }

  /// Whether the bus is predicted to be on time (delay <= 2 min).
  bool get isOnTime => predictedDelayMinutes <= 2;

  /// Whether there's a minor delay (2 < delay <= 10 min).
  bool get isMinorDelay =>
      predictedDelayMinutes > 2 && predictedDelayMinutes <= 10;

  /// Whether there's a major delay (delay > 10 min).
  bool get isMajorDelay => predictedDelayMinutes > 10;

  @override
  String toString() =>
      'Prediction(delay: ${predictedDelayMinutes.toStringAsFixed(1)}min, '
      'confidence: $confidenceLevel, samples: $sampleSize)';
}
