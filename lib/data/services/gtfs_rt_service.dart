/// Service for fetching GTFS-Realtime (GTFS-RT) Trip Updates from BODS API.
///
/// Returns genuine real-time arrival estimates and stop-level delays.
/// Returns an empty list if real-time tracking is unavailable or lost (never fabricates mock data).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../models/gtfs_rt_model.dart';

class GtfsRtService {
  static String get _backendBaseUrl => ApiConfig.backendBaseUrl;

  // In-memory cache
  static final Map<String, _CacheEntry<List<GtfsRtTripUpdate>>> _cache = {};
  static const _cacheTtl = Duration(seconds: 15);

  /// Fetches GTFS-RT trip updates for an optional [routeNumber].
  Future<List<GtfsRtTripUpdate>> fetchTripUpdates({String? routeNumber}) async {
    final cacheKey = routeNumber?.trim().toUpperCase() ?? '__all__';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.value;
    }

    try {
      final queryParams = <String, String>{};
      if (routeNumber != null && routeNumber.trim().isNotEmpty) {
        queryParams['route'] = routeNumber.trim();
      }

      final uri = Uri.parse('$_backendBaseUrl/api/trip-updates').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      debugPrint('⚡ Fetching GTFS-RT trip updates from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'BusAlert/1.0',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> updatesJson = jsonBody['tripUpdates'] ?? [];

        final updates = updatesJson
            .map((item) => GtfsRtTripUpdate.fromJson(item as Map<String, dynamic>))
            .toList();

        debugPrint('⚡ Received ${updates.length} GTFS-RT trip updates from backend');
        _cache[cacheKey] = _CacheEntry(updates);
        return updates;
      } else {
        debugPrint('⚡ Backend /api/trip-updates returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚡ Backend /api/trip-updates fetch error: $e');
    }

    return [];
  }

  /// Clears cache.
  void clearCache() {
    _cache.clear();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime _createdAt = DateTime.now();

  _CacheEntry(this.value);

  bool get isExpired => DateTime.now().difference(_createdAt) > GtfsRtService._cacheTtl;
}
