/// Riverpod state notifier for the "Destination from My Location" journey planner.
///
/// Discovers direct bus journeys connecting the user's current GPS location
/// (or selected origin stop) to any selected destination stop in Cardiff.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/models/planned_journey.dart';
import '../../../data/repositories/bods_repository.dart';
import '../../../data/repositories/gtfs_repository.dart';
import '../../../data/services/stop_service.dart';

class JourneyPlannerState {
  final BusStop? originStop;
  final BusStop? destinationStop;
  final LatLng? userLocation;
  final double? walkingDistanceToOrigin;
  final bool isGpsDetected;
  final bool isLoading;
  final List<PlannedJourney> journeys;
  final List<PlannedJourney> allJourneys;
  final String? selectedRouteFilter;
  final List<BusStop> allStops;
  final String? error;

  const JourneyPlannerState({
    this.originStop,
    this.destinationStop,
    this.userLocation,
    this.walkingDistanceToOrigin,
    this.isGpsDetected = false,
    this.isLoading = false,
    this.journeys = const [],
    this.allJourneys = const [],
    this.selectedRouteFilter,
    this.allStops = const [],
    this.error,
  });

  /// Distinct route numbers available for the current origin-destination pair.
  List<String> get availableRoutes {
    final routes = <String>{};
    for (final j in allJourneys) {
      if (j.routeNumber.isNotEmpty) {
        routes.add(j.routeNumber);
      }
    }
    final sorted = routes.toList()..sort();
    return sorted;
  }

  JourneyPlannerState copyWith({
    BusStop? originStop,
    bool clearOrigin = false,
    BusStop? destinationStop,
    bool clearDestination = false,
    LatLng? userLocation,
    double? walkingDistanceToOrigin,
    bool? isGpsDetected,
    bool? isLoading,
    List<PlannedJourney>? journeys,
    List<PlannedJourney>? allJourneys,
    String? selectedRouteFilter,
    bool clearRouteFilter = false,
    List<BusStop>? allStops,
    String? error,
  }) {
    return JourneyPlannerState(
      originStop: clearOrigin ? null : (originStop ?? this.originStop),
      destinationStop:
          clearDestination ? null : (destinationStop ?? this.destinationStop),
      userLocation: userLocation ?? this.userLocation,
      walkingDistanceToOrigin:
          walkingDistanceToOrigin ?? this.walkingDistanceToOrigin,
      isGpsDetected: isGpsDetected ?? this.isGpsDetected,
      isLoading: isLoading ?? this.isLoading,
      journeys: journeys ?? this.journeys,
      allJourneys: allJourneys ?? this.allJourneys,
      selectedRouteFilter: clearRouteFilter
          ? null
          : (selectedRouteFilter ?? this.selectedRouteFilter),
      allStops: allStops ?? this.allStops,
      error: error,
    );
  }
}

class JourneyPlannerNotifier extends StateNotifier<JourneyPlannerState> {
  final GtfsRepository _gtfsRepository;
  final BodsRepository _bodsRepository;
  final StopService _stopService;

  JourneyPlannerNotifier({
    GtfsRepository? gtfsRepository,
    BodsRepository? bodsRepository,
    StopService? stopService,
  })  : _gtfsRepository = gtfsRepository ?? GtfsRepository(),
        _bodsRepository = bodsRepository ?? BodsRepository(),
        _stopService = stopService ?? StopService(),
        super(const JourneyPlannerState());

  /// Loads stop data into state if not already loaded.
  Future<void> initStops({List<BusStop>? stops}) async {
    if (state.allStops.isNotEmpty) return;
    try {
      final allStops = stops ?? await _stopService.getStops();
      state = state.copyWith(allStops: allStops);
      await _gtfsRepository.loadGtfsData();
    } catch (_) {}
  }

  /// Sets the origin stop and recalculates routes if destination is chosen.
  void setOriginStop(BusStop stop) {
    state = state.copyWith(
      originStop: stop,
      isGpsDetected: false,
    );
    _calculateJourneys();
  }

  /// Sets the destination stop and recalculates routes.
  void setDestinationStop(BusStop stop) {
    state = state.copyWith(destinationStop: stop);
    _calculateJourneys();
  }

  /// Swaps origin and destination stops.
  void swapStops() {
    if (state.originStop == null && state.destinationStop == null) return;
    final oldOrigin = state.originStop;
    final oldDest = state.destinationStop;
    state = state.copyWith(
      originStop: oldDest,
      destinationStop: oldOrigin,
      isGpsDetected: false,
      walkingDistanceToOrigin: null,
    );
    _calculateJourneys();
  }

  /// Automatically locates user and sets nearest stop as origin.
  Future<void> detectCurrentLocationAsOrigin({Position? testPosition}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      Position position;
      if (testPosition != null) {
        position = testPosition;
      } else {
        if (!await Geolocator.isLocationServiceEnabled()) {
          state = state.copyWith(
            isLoading: false,
            error: 'Location services are disabled.',
          );
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            state = state.copyWith(
              isLoading: false,
              error: 'Location permission denied.',
            );
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          state = state.copyWith(
            isLoading: false,
            error: 'Location permission permanently denied.',
          );
          return;
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
      }

      final stops = state.allStops.isNotEmpty
          ? state.allStops
          : await _stopService.getStops();

      final nearestResult = _stopService.findNearestStop(
        stops,
        position.latitude,
        position.longitude,
      );

      if (nearestResult != null) {
        final (nearestStop, distance) = nearestResult;
        state = state.copyWith(
          originStop: nearestStop,
          userLocation: LatLng(position.latitude, position.longitude),
          walkingDistanceToOrigin: distance,
          isGpsDetected: true,
          isLoading: false,
          allStops: stops,
        );
        _calculateJourneys();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'No bus stops found near current location.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to detect location: $e',
      );
    }
  }

  /// Calculates direct journeys between origin and destination with real-time delays.
  Future<void> _calculateJourneys() async {
    final origin = state.originStop;
    final dest = state.destinationStop;

    if (origin == null || dest == null) {
      state = state.copyWith(journeys: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _gtfsRepository.loadGtfsData();

      // Find direct scheduled journeys
      final originId = origin.atcoCode.isNotEmpty ? origin.atcoCode : origin.id.toString();
      final destId = dest.atcoCode.isNotEmpty ? dest.atcoCode : dest.id.toString();

      var scheduledJourneys = _gtfsRepository.findDirectJourneys(
        originStopId: originId,
        destinationStopId: destId,
      );

      // If no single-bus direct route connects the two stops, find 1-transfer connecting routes
      if (scheduledJourneys.isEmpty) {
        scheduledJourneys = _gtfsRepository.findConnectingJourneys(
          originStopId: originId,
          destinationStopId: destId,
        );
      }

      // Fuse with real-time BODS delay for each unique route
      final List<PlannedJourney> fusedJourneys = [];
      final Map<String, double?> routeDelays = {};

      for (final j in scheduledJourneys) {
        double? delay;
        if (routeDelays.containsKey(j.routeNumber)) {
          delay = routeDelays[j.routeNumber];
        } else {
          try {
            delay = await _bodsRepository.getAverageDelay(
              lineRef: j.routeNumber,
              stopLat: origin.latitude,
              stopLng: origin.longitude,
            );
            routeDelays[j.routeNumber] = delay;
          } catch (_) {
            routeDelays[j.routeNumber] = null;
          }
        }

        fusedJourneys.add(
          PlannedJourney(
            routeNumber: j.routeNumber,
            headsign: j.headsign,
            originStopId: j.originStopId,
            originStopName: origin.name,
            destinationStopId: j.destinationStopId,
            destinationStopName: dest.name,
            departureTime: j.departureTime,
            arrivalTime: j.arrivalTime,
            durationMinutes: j.durationMinutes,
            stopsCount: j.stopsCount,
            delayMinutes: delay,
            isLive: delay != null,
          ),
        );
      }

      final activeFilter = state.selectedRouteFilter?.trim().toUpperCase();
      final filteredJourneys = (activeFilter != null && activeFilter.isNotEmpty)
          ? fusedJourneys
              .where((j) => j.routeNumber.trim().toUpperCase() == activeFilter)
              .toList()
          : fusedJourneys;

      state = state.copyWith(
        allJourneys: fusedJourneys,
        journeys: filteredJourneys,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error calculating journey: $e',
      );
    }
  }

  /// Sets or clears preferred route filter (e.g., '11', '27', or null for all routes).
  void setRouteFilter(String? routeNumber) {
    final filter = (routeNumber != null && routeNumber.trim().isNotEmpty)
        ? routeNumber.trim()
        : null;

    if (filter == null) {
      state = state.copyWith(
        clearRouteFilter: true,
        journeys: state.allJourneys,
      );
    } else {
      final filtered = state.allJourneys
          .where((j) => j.routeNumber.trim().toUpperCase() == filter.toUpperCase())
          .toList();
      state = state.copyWith(
        selectedRouteFilter: filter,
        journeys: filtered,
      );
    }
  }

  /// Clears current search.
  void clear() {
    state = state.copyWith(
      clearOrigin: true,
      clearDestination: true,
      clearRouteFilter: true,
      journeys: [],
      allJourneys: [],
      error: null,
      walkingDistanceToOrigin: null,
      isGpsDetected: false,
    );
  }
}

/// Provider instance for journey planner.
final journeyPlannerProvider =
    StateNotifierProvider<JourneyPlannerNotifier, JourneyPlannerState>((ref) {
  return JourneyPlannerNotifier();
});
