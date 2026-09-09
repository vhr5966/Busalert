/// Riverpod provider for the interactive map screen.
///
/// Manages the list of stops displayed on the map. Stops are loaded from the official
/// static NaPTAN dataset for Cardiff. Delay status is fetched from live BODS data.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/services/bods_siri_service.dart';
import '../../../data/services/stop_service.dart';

final StopService _stopService = StopService();
final BodsSiriService _bodsSiriService = BodsSiriService();

/// Map state including static NaPTAN stops and real delay statuses.
class MapState {
  final List<BusStop> stops;
  final Map<int, StopDelayStatus> delayStatuses;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const MapState({
    this.stops = const [],
    this.delayStatuses = const {},
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  /// Returns stops filtered by [searchQuery] against stop name, ID, or route numbers.
  List<BusStop> get filteredStops {
    if (searchQuery.trim().isEmpty) return stops;
    final query = searchQuery.trim().toLowerCase();
    return stops.where((stop) {
      final matchesName = stop.name.toLowerCase().contains(query);
      final matchesId = stop.id.toString().contains(query);
      final matchesRoute = stop.routes.any((r) => r.toLowerCase().contains(query));
      return matchesName || matchesId || matchesRoute;
    }).toList();
  }

  MapState copyWith({
    List<BusStop>? stops,
    Map<int, StopDelayStatus>? delayStatuses,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return MapState(
      stops: stops ?? this.stops,
      delayStatuses: delayStatuses ?? this.delayStatuses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Delay status for colour-coding a stop on the map.
enum StopDelayStatus { onTime, minorDelay, majorDelay, unknown }

class MapNotifier extends StateNotifier<MapState> {
  MapNotifier() : super(const MapState());

  /// Loads official Cardiff bus stops from the NaPTAN dataset and fetches delay data.
  Future<void> loadStops() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final stops = await _stopService.getStops();
      
      // Initialize with unknown status
      final delayStatuses = <int, StopDelayStatus>{};
      for (final stop in stops) {
        delayStatuses[stop.id] = StopDelayStatus.unknown;
      }

      state = MapState(
        stops: stops,
        delayStatuses: delayStatuses,
        isLoading: false,
        searchQuery: state.searchQuery,
      );

      // Fetch delay data in background (don't block UI)
      _fetchDelayData(stops);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load stops: $e',
      );
    }
  }

  /// Fetches real delay data for stops with route information.
  Future<void> _fetchDelayData(List<BusStop> stops) async {
    try {
      // Get all live vehicles
      final vehicles = await _bodsSiriService.fetchVehicles();

      // Group vehicles by normalized route number (strip CBUS:, FCYM:, etc.)
      final routeDelays = <String, List<double>>{};
      for (final vehicle in vehicles) {
        if (vehicle.delayMinutes != null) {
          final rawRoute = vehicle.publishedLineName.isNotEmpty 
              ? vehicle.publishedLineName 
              : vehicle.lineRef;
          final normalizedRoute = rawRoute.contains(':')
              ? rawRoute.split(':').last.trim().toLowerCase()
              : rawRoute.trim().toLowerCase();
          
          if (normalizedRoute.isNotEmpty) {
            routeDelays.putIfAbsent(normalizedRoute, () => []).add(vehicle.delayMinutes!);
          }
        }
      }

      // Calculate average delay per normalized route
      final routeAverageDelays = <String, double>{};
      routeDelays.forEach((route, delays) {
        if (delays.isNotEmpty) {
          routeAverageDelays[route] = delays.reduce((a, b) => a + b) / delays.length;
        }
      });

      // Update stop statuses
      final updatedStatuses = Map<int, StopDelayStatus>.from(state.delayStatuses);
      
      for (final stop in stops) {
        double? matchedDelay;

        // 1. Check if any route serving this stop has recorded live delay
        for (final r in stop.routes) {
          final norm = r.toLowerCase().trim();
          final delay = routeAverageDelays[norm];
          if (delay != null) {
            if (matchedDelay == null || delay > matchedDelay) {
              matchedDelay = delay;
            }
          }
        }

        // 2. If no direct route match, check proximity to live vehicles (within ~1.5 km)
        if (matchedDelay == null && vehicles.isNotEmpty) {
          for (final v in vehicles) {
            final latDiff = (v.latitude - stop.latitude).abs();
            final lngDiff = (v.longitude - stop.longitude).abs();
            if (latDiff < 0.015 && lngDiff < 0.015 && v.delayMinutes != null) {
              matchedDelay = v.delayMinutes;
              break;
            }
          }
        }

        // Assign status color
        if (matchedDelay != null) {
          if (matchedDelay <= 2) {
            updatedStatuses[stop.id] = StopDelayStatus.onTime;
          } else if (matchedDelay <= 10) {
            updatedStatuses[stop.id] = StopDelayStatus.minorDelay;
          } else {
            updatedStatuses[stop.id] = StopDelayStatus.majorDelay;
          }
        } else {
          // If no live tracking delay is available, mark as unknown / no data
          updatedStatuses[stop.id] = StopDelayStatus.unknown;
        }
      }

      state = state.copyWith(delayStatuses: updatedStatuses);
    } catch (e) {
      // Silent fail - delay data is optional, don't break the map
      debugPrint('Failed to fetch delay data: $e');
    }
  }

  /// Updates search query for filtering bus stops.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clears current search query.
  void clearSearchQuery() {
    state = state.copyWith(searchQuery: '');
  }

  /// Refreshes delay data for all stops without reloading the stop list.
  Future<void> refreshDelayData() async {
    if (state.stops.isEmpty) return;
    await _fetchDelayData(state.stops);
  }
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});
