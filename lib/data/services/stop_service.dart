/// Service for fetching Cardiff Bus stop data.
/// Service for fetching Cardiff Bus stop data.
///
/// Always uses the comprehensive NaPTAN dataset for reliability.
/// Applies route-stop mappings from the GTFS data (kGtfsStopRouteNames)
/// which covers all 1 650 stops with zero empty route sets.
/// Always uses the comprehensive NaPTAN dataset for reliability.
/// Applies route-stop mappings from the GTFS data (kGtfsStopRouteNames)
/// which covers all 1 650 stops with zero empty route sets.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../cardiff_bus_stops.dart' as cardiff_stops;
import '../gtfs_stop_routes.dart';
import '../cardiff_bus_stops.dart' as cardiff_stops;
import '../gtfs_stop_routes.dart';
import '../models/bus_stop.dart';

class StopService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static List<BusStop>? _cachedStops;

  /// Fetches the comprehensive list of Cardiff and regional bus stops.
  ///
  /// Uses the NaPTAN dataset and enriches each stop with its GTFS-derived
  /// route list from [kGtfsStopRouteNames] (covering Cardiff, Vale of Glamorgan, and Newport).
  Future<List<BusStop>> getStops() async {
    if (_cachedStops != null && _cachedStops!.isNotEmpty) {
      return _cachedStops!;
    }

    final Set<String> seenIdentifiers = {};
    final List<BusStop> uniqueStops = [];

    for (final json in cardiff_stops.kNaPTANBusStops) {
      final stopJson = Map<String, dynamic>.from(json);
      final atcoCode = stopJson['atcoCode'] as String? ?? '';
      final lat = (stopJson['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (stopJson['longitude'] as num?)?.toDouble() ?? 0.0;
      final name = stopJson['name'] as String? ?? '';

      final key = atcoCode.isNotEmpty
          ? atcoCode
          : '$name-${lat.toStringAsFixed(4)}-${lon.toStringAsFixed(4)}';
      if (!seenIdentifiers.add(key)) continue;

      if (atcoCode.isNotEmpty && kGtfsStopRouteNames.containsKey(atcoCode)) {
        stopJson['routes'] = kGtfsStopRouteNames[atcoCode];
      }
      uniqueStops.add(BusStop.fromJson(stopJson));
    }

    _cachedStops = uniqueStops;
    return uniqueStops;
  }

  /// Seeds the `bus_stops` Firestore collection with the comprehensive list
  /// of Cardiff Bus stops from the NaPTAN dataset.
  /// of Cardiff Bus stops from the NaPTAN dataset.
  ///
  /// Uses a batched write for efficiency. Each stop is written with its
  /// ATCO code as the document name so updates are idempotent.
  /// ATCO code as the document name so updates are idempotent.
  Future<void> seedFirestore() async {
    const batchSize = 500; // Firestore max batch size
    final stops = cardiff_stops.kNaPTANBusStops;
    final stops = cardiff_stops.kNaPTANBusStops;

    for (int i = 0; i < stops.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = stops.sublist(
        i,
        (i + batchSize).clamp(0, stops.length),
      );

      for (final stopJson in chunk) {
        final docId = stopJson['atcoCode'] as String? ?? stopJson['id'].toString();
        final docId = stopJson['atcoCode'] as String? ?? stopJson['id'].toString();
        final ref = _firestore.collection(kStopsCollection).doc(docId);
        batch.set(ref, {
          'name': stopJson['name'],
          'latitude': stopJson['latitude'],
          'longitude': stopJson['longitude'],
          'routes': stopJson['routes'] ?? [],
          'indicator': stopJson['indicator'] ?? '',
          'street': stopJson['street'] ?? '',
          'routes': stopJson['routes'] ?? [],
          'indicator': stopJson['indicator'] ?? '',
          'street': stopJson['street'] ?? '',
        });
      }

      await batch.commit();
    }
  }

  /// Finds the nearest bus stop to a GPS coordinate.
  ///
  /// Returns the closest stop and its distance in metres.
  /// Returns null if [stops] is empty.
  (BusStop stop, double distance)? findNearestStop(
    List<BusStop> stops,
    double lat,
    double lng,
  ) {
    if (stops.isEmpty) return null;

    BusStop nearest = stops.first;
    double minDistance = nearest.distanceTo(lat, lng);

    for (final stop in stops) {
      final distance = stop.distanceTo(lat, lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = stop;
      }
    }

    return (nearest, minDistance);
  }

  /// Returns stops filtered by route number.
  ///
  /// If [routeNumber] is null or empty, returns all stops.
  /// Otherwise, returns only stops that serve the specified route.
  Future<List<BusStop>> getStopsForRoute(String? routeNumber) async {
    final allStops = await getStops();
    if (routeNumber == null || routeNumber.isEmpty) {
      return allStops;
    }
    return allStops.where((stop) => stop.servesRoute(routeNumber)).toList();
  }

  /// Returns stops within the given bounds.
  ///
  /// Useful for map viewport filtering to improve performance.
  Future<List<BusStop>> getStopsInBounds({
    required double southWestLat,
    required double southWestLng,
    required double northEastLat,
    required double northEastLng,
  }) async {
    final allStops = await getStops();
    return allStops.where((stop) {
      return stop.latitude >= southWestLat &&
          stop.latitude <= northEastLat &&
          stop.longitude >= southWestLng &&
          stop.longitude <= northEastLng;
    }).toList();
  }

  /// Returns stops filtered by route number.
  ///
  /// If [routeNumber] is null or empty, returns all stops.
  /// Otherwise, returns only stops that serve the specified route.
  Future<List<BusStop>> getStopsForRoute(String? routeNumber) async {
    final allStops = await getStops();
    if (routeNumber == null || routeNumber.isEmpty) {
      return allStops;
    }
    return allStops.where((stop) => stop.servesRoute(routeNumber)).toList();
  }

  /// Returns stops within the given bounds.
  ///
  /// Useful for map viewport filtering to improve performance.
  Future<List<BusStop>> getStopsInBounds({
    required double southWestLat,
    required double southWestLng,
    required double northEastLat,
    required double northEastLng,
  }) async {
    final allStops = await getStops();
    return allStops.where((stop) {
      return stop.latitude >= southWestLat &&
          stop.latitude <= northEastLat &&
          stop.longitude >= southWestLng &&
          stop.longitude <= northEastLng;
    }).toList();
  }
}
