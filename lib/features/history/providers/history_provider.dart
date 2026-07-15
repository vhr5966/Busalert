/// Riverpod provider for journey history.
///
/// Loads the logged-in user's past journeys from Firestore via
/// [JourneyRepository] and provides them to the history screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_handler.dart';
import '../../../data/models/journey.dart';
import '../../../data/repositories/journey_repository.dart';

final JourneyRepository _journeyRepository = JourneyRepository();

/// State for the journey history feature.
class HistoryState {
  final List<Journey> journeys;
  final bool isLoading;
  final AppError? error;

  const HistoryState({
    this.journeys = const [],
    this.isLoading = false,
    this.error,
  });
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(const HistoryState());

  /// Fetches journey history from Firestore.
  Future<void> loadHistory() async {
    state = HistoryState(isLoading: true);

    try {
      final journeys = await _journeyRepository.getHistory();
      state = HistoryState(
        journeys: journeys,
        isLoading: false,
      );
    } catch (e) {
      state = HistoryState(
        isLoading: false,
        error: parseError(e),
      );
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
