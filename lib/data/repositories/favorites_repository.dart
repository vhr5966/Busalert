/// Repository for persisting pinned/favourite bus stops using SharedPreferences.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_stop.dart';

class FavoritesRepository {
  static const String _kFavoritesKey = 'pinned_bus_stops_v1';

  /// Returns the list of pinned/favourite bus stops.
  Future<List<BusStop>> getFavoriteStops() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kFavoritesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return BusStop(
          id: map['id'] as int,
          name: map['name'] as String? ?? 'Bus Stop',
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          routes: (map['routes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Toggles pinning/favouriting a bus stop.
  Future<bool> toggleFavoriteStop(BusStop stop) async {
    final current = await getFavoriteStops();
    final isFav = current.any((s) => s.id == stop.id);

    if (isFav) {
      current.removeWhere((s) => s.id == stop.id);
    } else {
      current.add(stop);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((s) => {
      'id': s.id,
      'name': s.name,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'routes': s.routes,
    }).toList();

    await prefs.setString(_kFavoritesKey, json.encode(jsonList));
    return !isFav; // returns true if now pinned
  }

  /// Checks if a stop is pinned.
  Future<bool> isFavorite(int stopId) async {
    final current = await getFavoriteStops();
    return current.any((s) => s.id == stopId);
  }
}
