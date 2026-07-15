/// Riverpod provider for the interactive map screen.
///
/// Manages the list of stops displayed on the map and their delay status
/// colour-coding. Stops are loaded from Firestore via [StopService].
/// Delay statuses are fetched via the `getPrediction` Cloud Function,
/// falling back to a mock distribution if the function is unavailable.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/bus_stop.dart';
import '../../../data/repositories/prediction_repository.dart';
import '../../../data/services/stop_service.dart';

final StopService _stopService = StopService();
final PredictionRepository _predictionRepository = PredictionRepository();

/// Map state including stops and their delay statuses.
class MapState {
  final List<BusStop> stops;
  final Map<int, StopDelayStatus> delayStatuses;
  final bool isLoading;
  final String? error;

  const MapState({
    this.stops = const [],
    this.delayStatuses = const {},
    this.isLoading = false,
    this.error,
  });
}

/// Simplified delay status for colour-coding a stop on the map.
enum StopDelayStatus { onTime, minorDelay, majorDelay, unknown }

class MapNotifier extends StateNotifier<MapState> {
  MapNotifier() : super(const MapState());

  /// Loads bus stops and fetches real delay predictions for each stop.
  ///
  /// Uses the current time of day and a representative bus line per stop
  /// to query the Cloud Function. Falls back to a mock distribution if
  /// the Cloud Function is unavailable.
  Future<void> loadStops() async {
    state = const MapState(isLoading: true);

    try {
      final stops = await _stopService.getStops();
      final now = DateTime.now();
      final timeOfDay = DateFormat('HH:mm').format(now);

      // Fetch predictions for all stops concurrently to keep loading fast.
      // We use a representative Cardiff Bus line (route 28, which serves
      // most city centre stops) as the default line for the map view.
      // Users can get stop-specific predictions via the Prediction screen.
      const defaultLine = '28';
      final predictions = await Future.wait(
        stops.map((stop) async {
          try {
            final p = await _predictionRepository.getPrediction(
              stopId: stop.id.toString(),
              busLine: defaultLine,
              timeOfDay: timeOfDay,
            );
            return MapEntry(stop.id, _statusFromDelay(p.predictedDelayMinutes));
          } catch (_) {
            return MapEntry(stop.id, _fallbackStatus(stop.id));
          }
        }),
      );

      state = MapState(
        stops: stops,
        delayStatuses: Map.fromEntries(predictions),
        isLoading: false,
      );
    } catch (e) {
      state = MapState(
        isLoading: false,
        error: 'Failed to load stops: $e',
      );
    }
  }

  /// Maps a predicted delay in minutes to a [StopDelayStatus].
  StopDelayStatus _statusFromDelay(double delayMinutes) {
    if (delayMinutes <= 2) return StopDelayStatus.onTime;
    if (delayMinutes <= 10) return StopDelayStatus.minorDelay;
    return StopDelayStatus.majorDelay;
  }

  /// Returns a varied fallback delay status based on the stop ID.
  /// Used when the Cloud Function is unavailable.
  StopDelayStatus _fallbackStatus(int stopId) {
    final statuses = [
      StopDelayStatus.onTime,
      StopDelayStatus.onTime,
      StopDelayStatus.onTime,
      StopDelayStatus.minorDelay,
      StopDelayStatus.minorDelay,
      StopDelayStatus.majorDelay,
    ];
    return statuses[stopId % statuses.length];
  }
}

final mapProvider = StateNotifierProvider<MapNotifier, MapState>((ref) {
  return MapNotifier();
});
