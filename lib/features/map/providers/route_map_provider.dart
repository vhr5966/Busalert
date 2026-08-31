/// Riverpod provider for managing multi-route GTFS map state, route line shapes,
/// color coding, live bus toggle, and missing shape warnings.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/bods_vehicle.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/bods_repository.dart';
import '../../../data/repositories/gtfs_repository.dart';

/// Preset palette of distinct, vibrant map line colors for selected routes.
const List<Color> kRouteColorPalette = [
  Color(0xFF003882), // Cardiff Blue
  Color(0xFFD32F2F), // Crimson Red
  Color(0xFF388E3C), // Emerald Green
  Color(0xFFF57C00), // Amber / Dark Orange
  Color(0xFF7B1FA2), // Deep Purple
  Color(0xFF0097A7), // Teal / Cyan
  Color(0xFFC2185B), // Magenta / Rose
  Color(0xFF5D4037), // Brown
  Color(0xFF455A64), // Slate / Blue Grey
];

class RouteMapState {
  final Set<String> selectedRouteNumbers;
  final bool showLiveBuses;
  final bool isLoadingGtfs;
  final bool isLoadingLiveBuses;
  final Map<String, List<List<LatLng>>> routePolylines; // route -> list of shape polylines
  final Map<String, List<BusStop>> routeStops; // route -> ordered stops
  final Map<String, Color> routeColors; // route -> assigned color
  final List<BodsVehicle> liveBuses;
  final List<String> unavailableRouteShapes;
  final List<BusStop> allStops;
  final String? error;

  const RouteMapState({
    this.selectedRouteNumbers = const {},
    this.showLiveBuses = false,
    this.isLoadingGtfs = true,
    this.isLoadingLiveBuses = false,
    this.routePolylines = const {},
    this.routeStops = const {},
    this.routeColors = const {},
    this.liveBuses = const [],
    this.unavailableRouteShapes = const [],
    this.allStops = const [],
    this.error,
  });

  RouteMapState copyWith({
    Set<String>? selectedRouteNumbers,
    bool? showLiveBuses,
    bool? isLoadingGtfs,
    bool? isLoadingLiveBuses,
    Map<String, List<List<LatLng>>>? routePolylines,
    Map<String, List<BusStop>>? routeStops,
    Map<String, Color>? routeColors,
    List<BodsVehicle>? liveBuses,
    List<String>? unavailableRouteShapes,
    List<BusStop>? allStops,
    String? error,
  }) {
    return RouteMapState(
      selectedRouteNumbers: selectedRouteNumbers ?? this.selectedRouteNumbers,
      showLiveBuses: showLiveBuses ?? this.showLiveBuses,
      isLoadingGtfs: isLoadingGtfs ?? this.isLoadingGtfs,
      isLoadingLiveBuses: isLoadingLiveBuses ?? this.isLoadingLiveBuses,
      routePolylines: routePolylines ?? this.routePolylines,
      routeStops: routeStops ?? this.routeStops,
      routeColors: routeColors ?? this.routeColors,
      liveBuses: liveBuses ?? this.liveBuses,
      unavailableRouteShapes: unavailableRouteShapes ?? this.unavailableRouteShapes,
      allStops: allStops ?? this.allStops,
      error: error,
    );
  }
}

class RouteMapNotifier extends StateNotifier<RouteMapState> {
  final GtfsRepository _gtfsRepository;
  final BodsRepository _bodsRepository;
  Timer? _liveRefreshTimer;

  RouteMapNotifier({
    GtfsRepository? gtfsRepository,
    BodsRepository? bodsRepository,
  })  : _gtfsRepository = gtfsRepository ?? GtfsRepository(),
        _bodsRepository = bodsRepository ?? BodsRepository(),
        super(const RouteMapState());

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  /// Initialized GTFS data loading.
  Future<void> initGtfs({
    String? routesCsv,
    String? tripsCsv,
    String? stopsCsv,
    String? stopTimesCsv,
    String? shapesCsv,
  }) async {
    state = state.copyWith(isLoadingGtfs: true);
    try {
      await _gtfsRepository.loadGtfsData(
        routesCsv: routesCsv,
        tripsCsv: tripsCsv,
        stopsCsv: stopsCsv,
        stopTimesCsv: stopTimesCsv,
        shapesCsv: shapesCsv,
      );
      final allStops = _gtfsRepository.getAllStops();
      state = state.copyWith(
        isLoadingGtfs: false,
        allStops: allStops,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingGtfs: false,
        error: 'Failed to load GTFS data: $e',
      );
    }
  }

  /// Toggles a route's selection status (multi-select).
  void toggleRouteSelection(String routeNumber) {
    final updated = Set<String>.from(state.selectedRouteNumbers);
    if (updated.contains(routeNumber)) {
      updated.remove(routeNumber);
    } else {
      updated.add(routeNumber);
    }
    _updateSelectedRoutes(updated);
  }

  /// Sets exact selection set.
  void setSelectedRoutes(Set<String> routeNumbers) {
    _updateSelectedRoutes(routeNumbers);
  }

  /// Clears all route selections.
  void clearSelection() {
    _updateSelectedRoutes({});
  }

  /// Toggles the "Show live buses" feature.
  void toggleLiveBuses(bool enabled) {
    state = state.copyWith(showLiveBuses: enabled);
    if (enabled) {
      _fetchLiveBuses();
      _startLivePolling();
    } else {
      _stopLivePolling();
      state = state.copyWith(liveBuses: []);
    }
  }

  void _startLivePolling() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.showLiveBuses) {
        _fetchLiveBuses();
      }
    });
  }

  void _stopLivePolling() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
  }

  Future<void> _fetchLiveBuses() async {
    if (!state.showLiveBuses) return;
    state = state.copyWith(isLoadingLiveBuses: true);
    try {
      final allLive = await _bodsRepository.getAllVehicles();

      // Filter live buses matching selected route(s).
      // Uses BodsVehicle.matchesRoute() which handles operator prefixes
      // (e.g. CBUS:27, FCYM:304), case insensitivity, and leading zeros.
      final List<BodsVehicle> filtered;
      if (state.selectedRouteNumbers.isEmpty) {
        // No specific route selected -> show all active live buses in Cardiff
        filtered = allLive;
      } else {
        // STRICT FILTER: Show ONLY live buses matching selected route(s)
        filtered = allLive
            .where((v) =>
                state.selectedRouteNumbers.any((r) => v.matchesRoute(r)))
            .toList();
      }

      state = state.copyWith(
        isLoadingLiveBuses: false,
        liveBuses: filtered,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingLiveBuses: false,
        liveBuses: [],
      );
    }
  }

  void _updateSelectedRoutes(Set<String> routes) {
    final Map<String, List<List<LatLng>>> newPolylines = {};
    final Map<String, List<BusStop>> newStops = {};
    final Map<String, Color> newColors = {};
    final List<String> missingShapes = [];

    int colorIndex = 0;
    for (final r in routes) {
      final shapes = _gtfsRepository.getShapesForRoute(r);
      final stops = _gtfsRepository.getStopsForRoute(r);

      if (shapes.isEmpty) {
        missingShapes.add(r);
      } else {
        newPolylines[r] = shapes;
      }

      newStops[r] = stops;
      newColors[r] = kRouteColorPalette[colorIndex % kRouteColorPalette.length];
      colorIndex++;
    }

    state = state.copyWith(
      selectedRouteNumbers: routes,
      routePolylines: newPolylines,
      routeStops: newStops,
      routeColors: newColors,
      unavailableRouteShapes: missingShapes,
    );

    if (state.showLiveBuses) {
      _fetchLiveBuses();
    }
  }
}

final routeMapProvider =
    StateNotifierProvider<RouteMapNotifier, RouteMapState>((ref) {
  return RouteMapNotifier();
});
