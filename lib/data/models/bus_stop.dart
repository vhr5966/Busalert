/// Model representing a Cardiff Bus stop with its GPS coordinates.
///
/// Used throughout the app for stop selection, map markers, and
/// boarding/alighting detection.
///
/// The `routes` field lists which bus routes serve this stop, enabling
/// route-based filtering in the prediction screen.
///
/// The `atcoCode` field preserves the original NaPTAN ATCO code (e.g.
/// "5710AWA10722"), which is used as the stop_id in the GTFS feed and
/// is required to look up routes from [GtfsStopRoutesService].
library;

import 'dart:math' show cos, pi, pow, sin, sqrt, atan2;

class BusStop {
  final int id;

  /// Original NaPTAN ATCO code, e.g. "5710AWA10722".
  ///
  /// This is the key used in the GTFS stop_times.txt feed and in
  /// [kGtfsStopRouteNames]. Empty string for stops without an ATCO code.
  final String atcoCode;

  final String name;
  final double latitude;
  final double longitude;
  final List<String> routes;

  const BusStop({
    required this.id,
    this.atcoCode = '',
    required this.name,
    required this.latitude,
    required this.longitude,
    this.routes = const [],
  });

  /// Creates a [BusStop] from a JSON map.
  ///
  /// Supports both int and String IDs (Firestore doc IDs are strings,
  /// while static NaPTAN reference stops use int IDs).
  factory BusStop.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'] ?? json['atcoCode'];
    final String atcoCode =
        (json['atcoCode'] as String?) ?? (idValue is String ? idValue : '');
    final dynamic routesValue = json['routes'];
    
    List<String> routes = [];
    if (routesValue is List) {
      routes = routesValue.map((e) => e.toString()).toList();
    }
    
    return BusStop(
      id: idValue is String ? idValue.hashCode : (idValue as int),
      atcoCode: atcoCode,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      routes: routes,
    );
  }

  /// Serializes to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'atcoCode': atcoCode,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'routes': routes,
    };
  }

  /// Returns true if this stop serves the specified route.
  ///
  /// Case-insensitive so live data refs (e.g. 'X2' vs 'x2' from BODS)
  /// still match the seed data.
  bool servesRoute(String routeNumber) {
    final normalized = routeNumber.toLowerCase();
    return routes.any((r) => r.toLowerCase() == normalized);
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
