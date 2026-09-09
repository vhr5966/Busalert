/// Riverpod provider for managing pinned/favourite bus stops and real-time delay statuses.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/services/bods_siri_service.dart';
import '../../map/providers/map_provider.dart' show StopDelayStatus;

final FavoritesRepository _favoritesRepository = FavoritesRepository();
final BodsSiriService _bodsSiriService = BodsSiriService();

class FavoritesState {
  final List<BusStop> favoriteStops;
  final Map<int, StopDelayStatus> delayStatuses;
  final Map<int, double?> delayMinutesMap;
  final bool isLoading;
  final DateTime? lastRefreshed;

  const FavoritesState({
    this.favoriteStops = const [],
    this.delayStatuses = const {},
    this.delayMinutesMap = const {},
    this.isLoading = true,
    this.lastRefreshed,
  });

  bool isPinned(int stopId) => favoriteStops.any((s) => s.id == stopId);

  FavoritesState copyWith({
    List<BusStop>? favoriteStops,
    Map<int, StopDelayStatus>? delayStatuses,
    Map<int, double?>? delayMinutesMap,
    bool? isLoading,
    DateTime? lastRefreshed,
  }) {
    return FavoritesState(
      favoriteStops: favoriteStops ?? this.favoriteStops,
      delayStatuses: delayStatuses ?? this.delayStatuses,
      delayMinutesMap: delayMinutesMap ?? this.delayMinutesMap,
      isLoading: isLoading ?? this.isLoading,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  Timer? _refreshTimer;

  FavoritesNotifier() : super(const FavoritesState()) {
    loadFavorites();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Loads pinned stops and starts 30s live delay auto-refresh.
  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true);
    final stops = await _favoritesRepository.getFavoriteStops();

    state = FavoritesState(
      favoriteStops: stops,
      isLoading: false,
      lastRefreshed: DateTime.now(),
    );

    if (stops.isNotEmpty) {
      fetchLiveDelays();
      _startTimer();
    }
  }

  /// Toggles pinning/unpinning a stop.
  Future<void> togglePin(BusStop stop) async {
    await _favoritesRepository.toggleFavoriteStop(stop);
    await loadFavorites();
  }

  /// Fetches real-time delay status for all pinned stops.
  Future<void> fetchLiveDelays() async {
    if (state.favoriteStops.isEmpty) return;

    try {
      final vehicles = await _bodsSiriService.fetchVehicles();

      final routeDelays = <String, double>{};
      for (final v in vehicles) {
        if (v.delayMinutes != null) {
          final raw = v.publishedLineName.isNotEmpty ? v.publishedLineName : v.lineRef;
          final norm = raw.contains(':') ? raw.split(':').last.trim().toLowerCase() : raw.trim().toLowerCase();
          routeDelays[norm] = v.delayMinutes!;
        }
      }

      final updatedStatuses = <int, StopDelayStatus>{};
      final updatedDelays = <int, double?>{};

      for (final stop in state.favoriteStops) {
        double? matchedDelay;

        // Route match
        for (final r in stop.routes) {
          final norm = r.toLowerCase().trim();
          if (routeDelays.containsKey(norm)) {
            matchedDelay = routeDelays[norm];
            break;
          }
        }

        // Proximity match
        if (matchedDelay == null && vehicles.isNotEmpty) {
          for (final v in vehicles) {
            if ((v.latitude - stop.latitude).abs() < 0.015 &&
                (v.longitude - stop.longitude).abs() < 0.015 &&
                v.delayMinutes != null) {
              matchedDelay = v.delayMinutes;
              break;
            }
          }
        }

        updatedDelays[stop.id] = matchedDelay;

        if (matchedDelay != null) {
          if (matchedDelay <= 2) {
            updatedStatuses[stop.id] = StopDelayStatus.onTime;
          } else if (matchedDelay <= 10) {
            updatedStatuses[stop.id] = StopDelayStatus.minorDelay;
          } else {
            updatedStatuses[stop.id] = StopDelayStatus.majorDelay;
          }
        } else {
          updatedStatuses[stop.id] = StopDelayStatus.unknown;
        }
      }

      state = state.copyWith(
        delayStatuses: updatedStatuses,
        delayMinutesMap: updatedDelays,
        lastRefreshed: DateTime.now(),
      );
    } catch (_) {
      // Keep existing state on transient fetch error
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchLiveDelays();
    });
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});
