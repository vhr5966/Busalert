/// Model representing a Cardiff Bus stop with its GPS coordinates.
///
/// Used throughout the app for stop selection, map markers, and
/// boarding/alighting detection.
library;

import 'dart:math' show cos, pi, pow, sin, sqrt, atan2;

class BusStop {
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  const BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Creates a [BusStop] from a JSON map.
  ///
  /// Supports both int and String IDs (Firestore doc IDs are strings,
  /// while the mock stops use int IDs).
  factory BusStop.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    return BusStop(
      id: idValue is String ? idValue.hashCode : (idValue as int),
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Serializes to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Calculates the Haversine distance (in metres) between this stop
  /// and a given [lat], [lng] coordinate.
  ///
  /// The Haversine formula accounts for the Earth's curvature, giving
  /// accurate distances over short ranges like city bus routes.
  double distanceTo(double lat, double lng) {
    const double earthRadius = 6371000; // metres

    final double dLat = _toRadians(lat - latitude);
    final double dLng = _toRadians(lng - longitude);
    final double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(lat)) *
            pow(sin(dLng / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  String toString() => 'BusStop(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusStop && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
