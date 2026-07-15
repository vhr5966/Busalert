/// Service for fetching Cardiff Bus stop data from Firestore.
///
/// Attempts to fetch from the `bus_stops` Firestore collection first.
/// Falls back to the hard-coded mock stops in [kMockBusStops] if Firestore
/// is unavailable (e.g. during development before Firebase is set up).
///
/// ## Seeding Firestore
///
/// Run [seedFirestore] once after project setup to populate the `bus_stops`
/// collection with the comprehensive list of Cardiff Bus stops defined in
/// [kMockBusStops]. This only needs to be done once per Firebase project.
/// Subsequent calls are no-ops if the collection is already populated.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../models/bus_stop.dart';

class StopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the list of Cardiff Bus stops from Firestore.
  ///
  /// Falls back to mock data if Firestore is unavailable or the collection
  /// is empty. The mock list in [kMockBusStops] now covers 30 stops across
  /// Cardiff city centre, north, east, west, and south/bay areas.
  Future<List<BusStop>> getStops() async {
    try {
      final querySnapshot =
          await _firestore.collection(kStopsCollection).orderBy('name').get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return BusStop.fromJson(data);
        }).toList();
      }

      // Collection exists but is empty — seed it automatically.
      await seedFirestore();
    } catch (_) {
      // Firestore unavailable — use mock stops
    }

    // Fallback to mock stops when Firestore is unavailable.
    return kMockBusStops
        .map((json) => BusStop.fromJson(json))
        .toList();
  }

  /// Seeds the `bus_stops` Firestore collection with the comprehensive list
  /// of Cardiff Bus stops from [kMockBusStops].
  ///
  /// Uses a batched write for efficiency. Each stop is written with its
  /// numeric ID as the document name so updates are idempotent.
  ///
  /// Safe to call multiple times — existing documents are overwritten with
  /// the same data (no duplicates created).
  Future<void> seedFirestore() async {
    const batchSize = 500; // Firestore max batch size
    final stops = kMockBusStops;

    for (int i = 0; i < stops.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = stops.sublist(
        i,
        (i + batchSize).clamp(0, stops.length),
      );

      for (final stopJson in chunk) {
        final docId = stopJson['id'].toString();
        final ref = _firestore.collection(kStopsCollection).doc(docId);
        batch.set(ref, {
          'name': stopJson['name'],
          'latitude': stopJson['latitude'],
          'longitude': stopJson['longitude'],
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
}
