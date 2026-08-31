/// Riverpod provider for delay prediction queries.
///
/// Manages the state of prediction requests — selecting a stop, bus line,
/// and time, then fetching the predicted delay via a Firebase Cloud Function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_handler.dart';
import '../../../data/models/bus_stop.dart';
import '../../../data/models/prediction.dart';
import '../../../data/repositories/prediction_repository.dart';
import '../../../data/services/stop_service.dart';

final PredictionRepository _predictionRepository = PredictionRepository();
final StopService _stopService = StopService();

/// State for the prediction query screen.
class PredictionQueryState {
  final List<BusStop> stops;
  final BusStop? selectedStop;
  final String? selectedBusLine;
  final String? selectedTime;
  final bool isLoading;
  final Prediction? result;
  final AppError? error;

  const PredictionQueryState({
    this.stops = const [],
    this.selectedStop,
    this.selectedBusLine,
    this.selectedTime,
    this.isLoading = false,
    this.result,
    this.error,
  });

  /// Returns stops filtered by the selected route.
  ///
  /// If no route is selected, returns all stops.
  /// If route filtering returns empty, falls back to all stops.
  List<BusStop> get filteredStops {
    if (selectedBusLine == null || selectedBusLine!.isEmpty) {
      return stops;
    }
    
    final filtered = stops.where((stop) => stop.servesRoute(selectedBusLine!)).toList();
    
    // Fall back to all stops if filtering returns empty
    if (filtered.isEmpty) {
      return stops;
    }
    
    return filtered;
  }

  PredictionQueryState copyWith({
    List<BusStop>? stops,
    BusStop? selectedStop,
    String? selectedBusLine,
    String? selectedTime,
    bool? isLoading,
    Prediction? result,
    AppError? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return PredictionQueryState(
      stops: stops ?? this.stops,
      selectedStop: selectedStop ?? this.selectedStop,
      selectedBusLine: selectedBusLine ?? this.selectedBusLine,
      selectedTime: selectedTime ?? this.selectedTime,
      isLoading: isLoading ?? this.isLoading,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PredictionNotifier extends StateNotifier<PredictionQueryState> {
  PredictionNotifier() : super(PredictionQueryState());

  /// Loads the list of available bus stops.
  ///
  /// On failure, sets an error state so the UI never silently shows
  /// "0 bus stops available" when the data could not be loaded.
  Future<void> loadStops() async {
    try {
      final stops = await _stopService.getStops();
      state = state.copyWith(stops: stops, clearError: true);
    } catch (e) {
      state = state.copyWith(error: parseError(e));
    }
  }

  /// Sets the selected bus stop.
  void selectStop(BusStop stop) {
    state = state.copyWith(selectedStop: stop, clearResult: true);
  }

  /// Sets the selected bus line.
  void selectBusLine(String line) {
    state = state.copyWith(selectedBusLine: line, clearResult: true);
  }

  /// Clears the selected bus line (e.g. when the stop changes).
  void clearBusLine() {
    state = PredictionQueryState(
      stops: state.stops,
      selectedStop: state.selectedStop,
      selectedBusLine: null,
      selectedTime: state.selectedTime,
      isLoading: state.isLoading,
    );
  }

  /// Sets the selected time of day.
  void selectTime(String time) {
    state = state.copyWith(selectedTime: time, clearResult: true);
  }

  /// Fetches a delay prediction from the Cloud Function.
  ///
  /// Falls back to mock data if the Cloud Function is unavailable.
  Future<void> fetchPrediction() async {
    final s = state;
    if (s.selectedStop == null ||
        s.selectedBusLine == null ||
        s.selectedTime == null) {
      return;
    }

    state = s.copyWith(isLoading: true, clearError: true, clearResult: true);

    try {
      final prediction = await _predictionRepository.getPrediction(
        stopId: s.selectedStop!.id.toString(),
        busLine: s.selectedBusLine!,
        timeOfDay: s.selectedTime!,
        stopName: s.selectedStop!.name,
      );

      state = state.copyWith(
        result: prediction,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: parseError(e),
      );
    }
  }

  void clearResult() {
    state = state.copyWith(clearResult: true);
  }
}

final predictionProvider =
    StateNotifierProvider<PredictionNotifier, PredictionQueryState>(
  (ref) => PredictionNotifier(),
);
