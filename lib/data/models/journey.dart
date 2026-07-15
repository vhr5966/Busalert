/// Model representing a single bus journey recorded by the user.
///
/// Each journey has a boarding point, an alighting point, a bus line,
/// and timestamps. Journey records are stored in the `journeys` Firestore
/// collection and are submitted via [JourneyRepository].
library;

class Journey {
  final int? id;
  final int userId;
  final int boardStopId;
  final String boardStopName;
  final double boardLat;
  final double boardLng;
  final int? alightStopId;
  final String? alightStopName;
  final double? alightLat;
  final double? alightLng;
  final String busLine;
  final DateTime boardingTime;
  final DateTime? alightingTime;

  const Journey({
    this.id,
    required this.userId,
    required this.boardStopId,
    required this.boardStopName,
    required this.boardLat,
    required this.boardLng,
    this.alightStopId,
    this.alightStopName,
    this.alightLat,
    this.alightLng,
    required this.busLine,
    required this.boardingTime,
    this.alightingTime,
  });

  /// Creates a [Journey] from a JSON map (from the backend API).
  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: json['id'] as int?,
      userId: json['user_id'] as int,
      boardStopId: json['board_stop_id'] as int,
      boardStopName: json['board_stop_name'] as String,
      boardLat: (json['board_lat'] as num).toDouble(),
      boardLng: (json['board_lng'] as num).toDouble(),
      alightStopId: json['alight_stop_id'] as int?,
      alightStopName: json['alight_stop_name'] as String?,
      alightLat: json['alight_lat'] != null
          ? (json['alight_lat'] as num).toDouble()
          : null,
      alightLng: json['alight_lng'] != null
          ? (json['alight_lng'] as num).toDouble()
          : null,
      busLine: json['bus_line'] as String,
      boardingTime: DateTime.parse(json['boarding_time'] as String),
      alightingTime: json['alighting_time'] != null
          ? DateTime.parse(json['alighting_time'] as String)
          : null,
    );
  }

  /// Serializes to JSON for API submission.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'board_stop_id': boardStopId,
      'board_stop_name': boardStopName,
      'board_lat': boardLat,
      'board_lng': boardLng,
      if (alightStopId != null) 'alight_stop_id': alightStopId,
      if (alightStopName != null) 'alight_stop_name': alightStopName,
      if (alightLat != null) 'alight_lat': alightLat,
      if (alightLng != null) 'alight_lng': alightLng,
      'bus_line': busLine,
      'boarding_time': boardingTime.toIso8601String(),
      if (alightingTime != null) 'alighting_time': alightingTime!.toIso8601String(),
    };
  }

  /// Calculates the journey duration in minutes.
  ///
  /// Returns null if the journey has not yet been completed (no alighting time).
  int? get durationMinutes {
    if (alightingTime == null) return null;
    return alightingTime!.difference(boardingTime).inMinutes;
  }

  @override
  String toString() =>
      'Journey(id: $id, bus: $busLine, from: $boardStopName, to: $alightStopName)';
}
