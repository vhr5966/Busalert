/// Riverpod provider for the live buses screen.
///
/// Polls real-time bus locations via [BodsRepository] every 30 seconds.
/// Displays truthful data and handles 2-minute staleness boundaries.
/// Never generates mock buses.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bods_config.dart';
import '../../../data/models/bods_vehicle.dart';
import '../../../data/repositories/bods_repository.dart';

final BodsRepository _bodsRepository = BodsRepository();

/// State for the live buses screen.
class LiveBusesState {
  /// Real-time live vehicles from the feed (unfiltered).
  final List<BodsVehicle> vehicles;

  /// Selected route filter, or null for all routes.
  final String? selectedRoute;

  /// True while the initial load is in progress.
  final bool isLoading;

  /// True while a background refresh is in progress.
  final bool isRefreshing;

  /// Truthful error message when live data is unavailable.
  final String? error;

  /// When the vehicle data was last fetched successfully.
  final DateTime? lastUpdated;

  const LiveBusesState({
    this.vehicles = const [],
    this.selectedRoute,
    this.isLoading = true,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  /// Vehicles filtered by the selected route.
  List<BodsVehicle> get visibleVehicles {
    final route = selectedRoute;
    if (route == null || route.isEmpty) return vehicles;
    return vehicles.where((v) => v.matchesRoute(route)).toList();
  }

  /// Whether data is older than 2 minutes (stale).
  bool get isStale {
    if (lastUpdated == null) return true;
    return DateTime.now().difference(lastUpdated!) > const Duration(minutes: 2);
  }

  /// Formatted relative timestamp string (e.g., "Updated 15s ago", "Last known data").
  String get statusTimestampLabel {
    if (lastUpdated == null) return '';
    final diff = DateTime.now().difference(lastUpdated!);
    if (diff.inMinutes >= 2) {
      return 'Last known data (${diff.inMinutes}m ago)';
    }
    if (diff.inMinutes >= 1) {
      return 'Updated ${diff.inMinutes}m ago';
    }
    return 'Updated ${diff.inSeconds}s ago';
  }

  LiveBusesState copyWith({
    List<BodsVehicle>? vehicles,
    String? selectedRoute,
    bool clearRoute = false,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    DateTime? lastUpdated,
  }) {
    return LiveBusesState(
      vehicles: vehicles ?? this.vehicles,
      selectedRoute: clearRoute ? null : (selectedRoute ?? this.selectedRoute),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class LiveBusesNotifier extends StateNotifier<LiveBusesState> {
  Timer? _pollTimer;
  int _startCount = 0;

  LiveBusesNotifier() : super(const LiveBusesState());

  /// Starts the 30-second server polling loop.
  void start() {
    _startCount++;
    if (_pollTimer != null) return;

    _fetchFromNetwork();

    _pollTimer = Timer.periodic(
      const Duration(seconds: BodsConfig.refreshIntervalSeconds),
      (_) => _fetchFromNetwork(),
    );
  }

  /// Stops the polling loop once the last screen disposes.
  void stop() {
    if (_startCount > 0) _startCount--;
    if (_startCount > 0) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Fetches real vehicle positions from backend / authorized provider.
  Future<void> _fetchFromNetwork() async {
    if (!mounted) return;
    state = state.copyWith(isRefreshing: true);

    try {
      final fetchedVehicles = await _bodsRepository
          .getAllVehicles()
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (fetchedVehicles.isNotEmpty) {
        state = LiveBusesState(
          vehicles: fetchedVehicles,
          selectedRoute: state.selectedRoute,
          isLoading: false,
          isRefreshing: false,
          error: null,
          lastUpdated: DateTime.now(),
        );
      } else {
        // If no vehicles returned, check if existing data is fresh (< 2 mins)
        final isPreviousFresh = state.lastUpdated != null &&
            DateTime.now().difference(state.lastUpdated!) <
                const Duration(minutes: 2);

        if (isPreviousFresh && state.vehicles.isNotEmpty) {
          state = state.copyWith(
            isLoading: false,
            isRefreshing: false,
          );
        } else {
          state = LiveBusesState(
            vehicles: const [],
            selectedRoute: state.selectedRoute,
            isLoading: false,
            isRefreshing: false,
            error: 'Live bus data is currently unavailable. Please try again later.',
            lastUpdated: state.lastUpdated,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;

      final isPreviousFresh = state.lastUpdated != null &&
          DateTime.now().difference(state.lastUpdated!) <
              const Duration(minutes: 2);

      if (isPreviousFresh && state.vehicles.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
        );
      } else {
        state = LiveBusesState(
          vehicles: const [],
          selectedRoute: state.selectedRoute,
          isLoading: false,
          isRefreshing: false,
          error: 'Live bus data is currently unavailable. Please try again later.',
          lastUpdated: state.lastUpdated,
        );
      }
    }
  }

  Future<void> refresh() => _fetchFromNetwork();

  void selectRoute(String? route) {
    state = state.copyWith(
      selectedRoute: route,
      clearRoute: route == null,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final liveBusesProvider =
    StateNotifierProvider<LiveBusesNotifier, LiveBusesState>((ref) {
  return LiveBusesNotifier();
});
