/// GTFS-Realtime (GTFS-RT) Trip Updates data models for true real-time arrival predictions.
///
/// Direct feed from UK Bus Open Data Service (BODS) providing estimated
/// arrival and departure timestamps per stop, stop-level delays, and overall trip delay.
library;

class GtfsRtStopTimeUpdate {
  final String stopId;
  final int? stopSequence;
  final int? arrivalDelaySeconds;
  final int? arrivalTime; // POSIX seconds
  final int? departureDelaySeconds;
  final int? departureTime; // POSIX seconds

  const GtfsRtStopTimeUpdate({
    required this.stopId,
    this.stopSequence,
    this.arrivalDelaySeconds,
    this.arrivalTime,
    this.departureDelaySeconds,
    this.departureTime,
  });

  factory GtfsRtStopTimeUpdate.fromJson(Map<String, dynamic> json) {
    return GtfsRtStopTimeUpdate(
      stopId: json['stopId']?.toString() ?? '',
      stopSequence: json['stopSequence'] as int?,
      arrivalDelaySeconds: (json['arrivalDelaySeconds'] as num?)?.toInt(),
      arrivalTime: (json['arrivalTime'] as num?)?.toInt(),
      departureDelaySeconds: (json['departureDelaySeconds'] as num?)?.toInt(),
      departureTime: (json['departureTime'] as num?)?.toInt(),
    );
  }

  /// Effective delay in seconds (departure delay preferred, then arrival delay).
  int? get effectiveDelaySeconds => departureDelaySeconds ?? arrivalDelaySeconds;

  /// Effective delay in minutes.
  double? get effectiveDelayMinutes {
    final s = effectiveDelaySeconds;
    return s != null ? s / 60.0 : null;
  }

  /// Estimated departure DateTime if absolute POSIX timestamp is available.
  DateTime? get estimatedDepartureDateTime {
    final t = departureTime ?? arrivalTime;
    if (t == null || t <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true).toLocal();
  }
}

class GtfsRtTripUpdate {
  final String tripId;
  final String routeId;
  final int? delaySeconds;
  final DateTime? timestamp;
  final List<GtfsRtStopTimeUpdate> stopTimeUpdates;

  const GtfsRtTripUpdate({
    required this.tripId,
    required this.routeId,
    this.delaySeconds,
    this.timestamp,
    this.stopTimeUpdates = const [],
  });

  factory GtfsRtTripUpdate.fromJson(Map<String, dynamic> json) {
    final stuList = (json['stopTimeUpdates'] as List<dynamic>?)
            ?.map((e) => GtfsRtStopTimeUpdate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final tsStr = json['timestamp'] as String?;

    return GtfsRtTripUpdate(
      tripId: json['tripId']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? '',
      delaySeconds: (json['delaySeconds'] as num?)?.toInt(),
      timestamp: tsStr != null ? DateTime.tryParse(tsStr) : null,
      stopTimeUpdates: stuList,
    );
  }

  /// Overall trip delay in minutes.
  double? get delayMinutes => delaySeconds != null ? delaySeconds! / 60.0 : null;

  /// Finds matching stop time update for [stopId] or [stopSequence].
  GtfsRtStopTimeUpdate? findUpdateForStop({String? stopId, int? stopSequence}) {
    if (stopId != null && stopId.isNotEmpty) {
      for (final update in stopTimeUpdates) {
        if (update.stopId == stopId) return update;
      }
    }
    if (stopSequence != null) {
      for (final update in stopTimeUpdates) {
        if (update.stopSequence == stopSequence) return update;
      }
    }
    return null;
  }

  /// Computes estimated departure time string (HH:mm) for a stop.
  ///
  /// Uses absolute POSIX timestamp if present; otherwise applies stop delay or trip delay to scheduled time.
  String? computeEstimatedDeparture({
    String? stopId,
    int? stopSequence,
    required String scheduledTimeHHmm,
    DateTime? relativeTo,
  }) {
    final stopUpdate = findUpdateForStop(stopId: stopId, stopSequence: stopSequence);

    // 1. Direct POSIX timestamp from GTFS-RT
    if (stopUpdate != null) {
      final dt = stopUpdate.estimatedDepartureDateTime;
      if (dt != null) {
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
    }

    // 2. Stop-level delay in seconds
    final effectiveDelay = stopUpdate?.effectiveDelaySeconds ?? delaySeconds;
    if (effectiveDelay != null) {
      final parts = scheduledTimeHHmm.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final baseDate = relativeTo ?? DateTime.now();
        final schedDT = DateTime(baseDate.year, baseDate.month, baseDate.day, h, m);
        final predDT = schedDT.add(Duration(seconds: effectiveDelay));
        final predH = predDT.hour.toString().padLeft(2, '0');
        final predM = predDT.minute.toString().padLeft(2, '0');
        return '$predH:$predM';
      }
    }

    return null;
  }
}
