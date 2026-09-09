/// Repository for BODS vehicle data with in-memory caching.
///
/// - Converts raw [BodsVehicle] data into delay minutes for the prediction UI
/// - Caches results to avoid duplicate API calls within the TTL window
library;

import '../models/bods_vehicle.dart';
import '../services/bods_siri_service.dart';

class BodsRepository {
  final BodsSiriService _service = BodsSiriService();

  // In-memory cache for vehicle data
  // Keyed by lineRef
  final Map<String, _CacheEntry<List<BodsVehicle>>> _vehicleCache = {};
  // Keyed by "$lineRef|$stopLat|$stopLng"
  final Map<String, _CacheEntry<double?>> _delayCache = {};

  static const _cacheTtl = Duration(seconds: 15);

  /// Returns the current average delay in minutes for [lineRef]
  /// near the given stop coordinates.
  ///
  /// Returns null if no data is available.
  Future<double?> getAverageDelay({
    required String lineRef,
    required double stopLat,
    required double stopLng,
  }) async {
    final cacheKey = '$lineRef|$stopLat|$stopLng';
    final cached = _delayCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    final delay = await _service.getAverageDelay(
      lineRef: lineRef,
      stopLat: stopLat,
      stopLng: stopLng,
    );

    _delayCache[cacheKey] = _CacheEntry(delay);
    return delay;
  }

  /// Returns all live Cardiff Bus vehicles for [lineRef].
  Future<List<BodsVehicle>> getVehiclesForLine(String lineRef) async {
    final cached = _vehicleCache[lineRef];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    final vehicles = await _service.fetchVehicles(lineRef: lineRef);
    _vehicleCache[lineRef] = _CacheEntry(vehicles);
    return vehicles;
  }

  /// Returns all live vehicles regardless of route.
  Future<List<BodsVehicle>> getAllVehicles() async {
    const cacheKey = '__all__';
    final cached = _vehicleCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    final vehicles = await _service.fetchVehicles();
    _vehicleCache[cacheKey] = _CacheEntry(vehicles);
    return vehicles;
  }

  /// Clears all cached data.
  void clearCache() {
    _vehicleCache.clear();
    _delayCache.clear();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime _createdAt = DateTime.now();

  _CacheEntry(this.value);

  bool get isExpired => DateTime.now().difference(_createdAt) > BodsRepository._cacheTtl;
}
