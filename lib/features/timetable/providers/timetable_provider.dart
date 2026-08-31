/// Riverpod provider for real-time timetable departures.
///
/// Manages fetching, auto-refreshing, and filtering real-time timetables for bus stops.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/gtfs_model.dart';
import '../../../data/repositories/timetable_repository.dart';

final TimetableRepository _timetableRepository = TimetableRepository();

class TimetableState {
  final BusStop? stop;
  final String? routeNumber;
  final List<TimetableEntry> departures;
  final bool isLoading;
  final DateTime? lastRefreshed;
  final String? error;

  const TimetableState({
    this.stop,
    this.routeNumber,
    this.departures = const [],
    this.isLoading = false,
    this.lastRefreshed,
    this.error,
  });

  TimetableState copyWith({
    BusStop? stop,
    String? routeNumber,
    List<TimetableEntry>? departures,
    bool? isLoading,
    DateTime? lastRefreshed,
    String? error,
    bool clearError = false,
  }) {
    return TimetableState(
      stop: stop ?? this.stop,
      routeNumber: routeNumber ?? this.routeNumber,
      departures: departures ?? this.departures,
      isLoading: isLoading ?? this.isLoading,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TimetableNotifier extends StateNotifier<TimetableState> {
  Timer? _refreshTimer;

  TimetableNotifier() : super(const TimetableState());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Sets stop and route filter, then loads real-time timetable departures.
  Future<void> setFilter({BusStop? stop, String? routeNumber}) async {
    state = state.copyWith(
      stop: stop,
      routeNumber: routeNumber,
      isLoading: true,
      clearError: true,
    );

    await _fetchDepartures();
    _startAutoRefresh();
  }

  /// Refreshes the current real-time timetable.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _fetchDepartures();
  }

  Future<void> _fetchDepartures() async {
    final stop = state.stop;
    if (stop == null) {
      state = state.copyWith(
        departures: [],
        isLoading: false,
      );
      return;
    }

    try {
      final entries = await _timetableRepository.getRealTimeTimetable(
        stop: stop,
        routeNumber: state.routeNumber,
      );

      state = state.copyWith(
        departures: entries,
        isLoading: false,
        lastRefreshed: DateTime.now(),
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update real-time timetable: $e',
      );
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Auto refresh real-time departures every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchDepartures();
    });
  }
}

final timetableProvider =
    StateNotifierProvider<TimetableNotifier, TimetableState>((ref) {
  return TimetableNotifier();
});
